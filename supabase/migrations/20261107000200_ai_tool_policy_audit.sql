-- FOUNDRY MIGRATION 0014: AI TOOL POLICY AND INVOCATION AUDIT
-- Target: Development database only (London / eu-west-2).
-- This migration records policy and lifecycle state; application code must still
-- enforce authorization before any external side effect or tool execution.

begin;

create type private.ai_tool_risk_level as enum (
  'low',
  'moderate',
  'high',
  'critical'
);

create type private.ai_tool_invocation_status as enum (
  'requested',
  'awaiting_confirmation',
  'approved',
  'rejected',
  'running',
  'succeeded',
  'failed',
  'cancelled'
);

create table private.ai_tool_definitions (
  id uuid primary key default gen_random_uuid(),
  tool_key text not null,
  version text not null,
  description text not null,
  input_schema jsonb not null,
  allowed_purposes public.ai_run_purpose[] not null,
  safety_profile public.ai_safety_profile not null default 'adult',
  risk_level private.ai_tool_risk_level not null default 'low',
  requires_user_confirmation boolean not null default false,
  is_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  enabled_at timestamptz,
  disabled_at timestamptz,

  constraint ai_tool_definitions_key_version_unique
    unique (tool_key, version),

  constraint ai_tool_definitions_key_format
    check (tool_key ~ '^[a-z0-9_]+$'),

  constraint ai_tool_definitions_version_not_empty
    check (length(trim(version)) > 0),

  constraint ai_tool_definitions_description_not_empty
    check (length(trim(description)) > 0),

  constraint ai_tool_definitions_input_schema_object
    check (jsonb_typeof(input_schema) = 'object'),

  constraint ai_tool_definitions_allowed_purposes_nonempty
    check (cardinality(allowed_purposes) > 0),

  constraint ai_tool_definitions_enable_state
    check (
      (is_enabled and enabled_at is not null and disabled_at is null)
      or (not is_enabled)
    ),

  constraint ai_tool_definitions_disable_state
    check (
      disabled_at is null
      or (enabled_at is not null and disabled_at >= enabled_at)
    ),

  constraint ai_tool_definitions_confirmation_for_risky_tools
    check (
      risk_level not in ('high', 'critical')
      or requires_user_confirmation
    )
);

create unique index ai_tool_definitions_one_enabled_version_idx
  on private.ai_tool_definitions (tool_key, safety_profile)
  where is_enabled;

create table private.ai_tool_invocations (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null,
  user_id uuid not null,
  tool_key text not null,
  tool_version text not null,
  status private.ai_tool_invocation_status not null default 'requested',
  request_hash text not null,
  result_hash text,
  confirmation_required boolean not null default false,
  confirmation_requested_at timestamptz,
  confirmed_at timestamptz,
  confirmed_by_user_id uuid references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  execution_started_at timestamptz,
  completed_at timestamptz,
  failure_code text,

  constraint ai_tool_invocations_run_owner_fk
    foreign key (run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint ai_tool_invocations_definition_fk
    foreign key (tool_key, tool_version)
    references private.ai_tool_definitions(tool_key, version)
    on delete restrict,

  constraint ai_tool_invocations_request_hash_format
    check (request_hash ~ '^[0-9a-f]{64}$'),

  constraint ai_tool_invocations_result_hash_format
    check (
      result_hash is null
      or result_hash ~ '^[0-9a-f]{64}$'
    ),

  constraint ai_tool_invocations_confirmation_state
    check (
      (
        confirmation_required = false
        and confirmation_requested_at is null
        and confirmed_at is null
        and confirmed_by_user_id is null
      )
      or
      (
        confirmation_required = true
        and (
          (confirmed_at is null and confirmed_by_user_id is null)
          or
          (
            confirmed_at is not null
            and confirmed_by_user_id = user_id
            and confirmation_requested_at is not null
          )
        )
      )
    ),

  constraint ai_tool_invocations_approval_state
    check (
      status <> 'approved'
      or (
        confirmation_required
        and confirmed_at is not null
        and confirmed_by_user_id = user_id
      )
    ),

  constraint ai_tool_invocations_execution_state
    check (
      status not in ('running', 'succeeded', 'failed')
      or execution_started_at is not null
    ),

  constraint ai_tool_invocations_completion_state
    check (
      (
        status in ('succeeded', 'failed', 'cancelled', 'rejected')
        and completed_at is not null
      )
      or
      (
        status not in ('succeeded', 'failed', 'cancelled', 'rejected')
        and completed_at is null
      )
    )
);

create index ai_tool_invocations_user_created_idx
  on private.ai_tool_invocations (user_id, created_at desc);

create index ai_tool_invocations_run_idx
  on private.ai_tool_invocations (run_id, created_at);

create index ai_tool_invocations_tool_idx
  on private.ai_tool_invocations (tool_key, tool_version, created_at desc);

-- Validate policy at creation and prevent invalid status jumps on every update.

create or replace function private.validate_ai_tool_invocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run_purpose public.ai_run_purpose;
  v_run_safety public.ai_safety_profile;
  v_tool private.ai_tool_definitions%rowtype;
begin
  if tg_op = 'INSERT' then

    select r.purpose, r.safety_profile
    into v_run_purpose, v_run_safety
    from public.ai_runs r
    where r.id = new.run_id
      and r.user_id = new.user_id;

    if not found then
      raise exception 'AI run not found for invocation owner';
    end if;

    select *
    into v_tool
    from private.ai_tool_definitions d
    where d.tool_key = new.tool_key
      and d.version = new.tool_version;

    if not found then
      raise exception 'Tool definition not found';
    end if;

    if not v_tool.is_enabled then
      raise exception 'Tool definition is disabled';
    end if;

    if not (v_run_purpose = any(v_tool.allowed_purposes)) then
      raise exception 'Tool is not permitted for this AI run purpose';
    end if;

    if v_run_safety <> v_tool.safety_profile then
      raise exception 'Tool safety profile does not match AI run';
    end if;

    if new.confirmation_required <> v_tool.requires_user_confirmation then
      raise exception 'Invocation confirmation requirement does not match tool policy';
    end if;

    if new.confirmation_required
       and new.status not in ('awaiting_confirmation', 'rejected') then
      raise exception 'A confirmation-required invocation must await confirmation before approval or execution';
    end if;

    if not new.confirmation_required
       and new.status not in ('requested', 'cancelled') then
      raise exception 'Invocation must start as requested when confirmation is not required';
    end if;

    if new.confirmation_required
       and new.confirmation_requested_at is null then
      new.confirmation_requested_at := new.created_at;
    end if;

    return new;
  end if;

  if new.run_id <> old.run_id
     or new.user_id <> old.user_id
     or new.tool_key <> old.tool_key
     or new.tool_version <> old.tool_version
     or new.request_hash <> old.request_hash
     or new.confirmation_required <> old.confirmation_required then
    raise exception 'Invocation identity and request fields are immutable';
  end if;

  if old.status <> new.status then
    if not (
      (old.status = 'requested' and new.status in ('running', 'cancelled'))
      or
      (old.status = 'awaiting_confirmation' and new.status in ('approved', 'rejected', 'cancelled'))
      or
      (old.status = 'approved' and new.status in ('running', 'cancelled'))
      or
      (old.status = 'running' and new.status in ('succeeded', 'failed', 'cancelled'))
    ) then
      raise exception
        'Invalid AI tool invocation status transition: % -> %',
        old.status,
        new.status;
    end if;
  end if;

  if new.confirmed_at is distinct from old.confirmed_at
     or new.confirmed_by_user_id is distinct from old.confirmed_by_user_id then

    if not new.confirmation_required
       or new.confirmed_at is null
       or new.confirmed_by_user_id <> new.user_id
       or new.confirmation_requested_at is null then
      raise exception 'Confirmation must be explicitly recorded by the invocation owner';
    end if;
  end if;

  if new.status = 'running' and old.status <> 'running' then

    if new.confirmation_required
       and (
         new.confirmed_at is null
         or new.confirmed_by_user_id <> new.user_id
       ) then
      raise exception 'User confirmation is required before execution';
    end if;

    select *
    into v_tool
    from private.ai_tool_definitions d
    where d.tool_key = new.tool_key
      and d.version = new.tool_version;

    if not found or not v_tool.is_enabled then
      raise exception 'Tool is no longer enabled';
    end if;

    select r.purpose, r.safety_profile
    into v_run_purpose, v_run_safety
    from public.ai_runs r
    where r.id = new.run_id
      and r.user_id = new.user_id;

    if not found
       or not (v_run_purpose = any(v_tool.allowed_purposes))
       or v_run_safety <> v_tool.safety_profile then
      raise exception 'Tool policy no longer matches the AI run';
    end if;

    new.execution_started_at := coalesce(new.execution_started_at, now());
  end if;

  if new.status in ('succeeded', 'failed', 'cancelled', 'rejected') then
    new.completed_at := coalesce(new.completed_at, now());
  end if;

  if new.status = 'succeeded' and new.result_hash is null then
    raise exception 'A successful invocation must include a result hash';
  end if;

  return new;
end;
$$;

create trigger ai_tool_invocations_validate
before insert or update on private.ai_tool_invocations
for each row
execute function private.validate_ai_tool_invocation();

comment on table private.ai_tool_definitions is
  'Server-only allowlist and policy metadata for AI tools. This table does not execute tools.';

comment on table private.ai_tool_invocations is
  'Server-side lifecycle and audit metadata. Raw tool arguments and results are not stored.';

alter table private.ai_tool_definitions
enable row level security;

alter table private.ai_tool_invocations
enable row level security;

revoke all on private.ai_tool_definitions
from public, anon, authenticated, service_role;

revoke all on private.ai_tool_invocations
from public, anon, authenticated, service_role;

revoke all on function private.validate_ai_tool_invocation()
from public, anon, authenticated;

grant usage on schema private to service_role;

grant select, insert, update
on private.ai_tool_definitions
to service_role;

grant select, insert, update
on private.ai_tool_invocations
to service_role;

commit;

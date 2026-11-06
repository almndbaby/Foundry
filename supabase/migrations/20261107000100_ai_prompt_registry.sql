-- FOUNDRY MIGRATION 0013: VERSIONED AI PROMPT REGISTRY
-- Target: Development database only (London / eu-west-2).
-- Published prompt content is immutable. Publish a new version to change it.

begin;

create table private.ai_prompt_templates (
  id uuid primary key default gen_random_uuid(),
  template_key text not null,
  version text not null,
  purpose public.ai_run_purpose not null,
  safety_profile public.ai_safety_profile not null default 'adult',
  system_prompt text not null,
  developer_prompt text,
  output_schema jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  is_active boolean not null default false,
  published_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz not null default now(),

  constraint ai_prompt_templates_key_version_unique
    unique (template_key, version),

  constraint ai_prompt_templates_key_format
    check (template_key ~ '^[a-z0-9_]+$'),

  constraint ai_prompt_templates_version_not_empty
    check (length(trim(version)) > 0),

  constraint ai_prompt_templates_system_prompt_not_empty
    check (length(trim(system_prompt)) > 0),

  constraint ai_prompt_templates_output_schema_object
    check (jsonb_typeof(output_schema) = 'object'),

  constraint ai_prompt_templates_settings_object
    check (jsonb_typeof(settings) = 'object'),

  constraint ai_prompt_templates_publish_state
    check (
      (published_at is null and is_active = false and retired_at is null)
      or
      (published_at is not null and (is_active = (retired_at is null)))
    ),

  constraint ai_prompt_templates_retirement_state
    check (
      retired_at is null
      or (published_at is not null and retired_at >= published_at)
    )
);

create unique index ai_prompt_templates_one_active_version_idx
  on private.ai_prompt_templates (template_key, purpose, safety_profile)
  where is_active;

create or replace function private.prevent_published_prompt_edits()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.published_at is not null and (
    new.template_key is distinct from old.template_key
    or new.version is distinct from old.version
    or new.purpose is distinct from old.purpose
    or new.safety_profile is distinct from old.safety_profile
    or new.system_prompt is distinct from old.system_prompt
    or new.developer_prompt is distinct from old.developer_prompt
    or new.output_schema is distinct from old.output_schema
    or new.settings is distinct from old.settings
    or new.published_at is distinct from old.published_at
  ) then
    raise exception 'Published prompt versions are immutable; create a new version.';
  end if;

  if old.retired_at is not null
     and new.retired_at is distinct from old.retired_at then
    raise exception 'A retired prompt version cannot be reactivated or have its retirement changed.';
  end if;

  if old.published_at is null
     and new.published_at is not null
     and new.retired_at is not null then
    raise exception 'A prompt cannot be published and retired in the same update.';
  end if;

  return new;
end;
$$;

create trigger ai_prompt_templates_immutable_published
before update on private.ai_prompt_templates
for each row
execute function private.prevent_published_prompt_edits();

comment on table private.ai_prompt_templates is
  'Server-only versioned AI prompts. Published prompt content is immutable; create a new version to change it.';

comment on column private.ai_prompt_templates.output_schema is
  'JSON Schema used by the server to validate structured model output.';

comment on column private.ai_prompt_templates.settings is
  'Non-secret model request settings only. Never store provider credentials or API keys.';

alter table private.ai_prompt_templates
enable row level security;

revoke all on private.ai_prompt_templates
from public, anon, authenticated, service_role;

revoke all on function private.prevent_published_prompt_edits()
from public, anon, authenticated;

grant usage on schema private to service_role;

grant select, insert, update
on private.ai_prompt_templates
to service_role;

commit;

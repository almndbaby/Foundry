-- =========================================================
-- FOUNDRY: MIGRATION 0004 — AI CORE
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.conversation_context_type as enum (
  'general',
  'discovery',
  'opportunity',
  'project'
);

create type public.message_role as enum (
  'user',
  'assistant',
  'system',
  'tool'
);

create type public.ai_run_purpose as enum (
  'chat',
  'discovery_inference',
  'opportunity_generation',
  'assessment',
  'research',
  'plan_drafting',
  'branding',
  'strategy'
);

create type public.ai_run_status as enum (
  'running',
  'succeeded',
  'failed',
  'cancelled'
);

create type public.ai_safety_profile as enum (
  'adult',
  'young_entrepreneur'
);

-- ---------------------------------------------------------
-- 2. AI RUNS
-- ---------------------------------------------------------

create table public.ai_runs (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  purpose public.ai_run_purpose not null,

  model_id text,
  prompt_template_key text not null,
  prompt_version text not null,

  input_tokens integer,
  output_tokens integer,
  cost_microusd bigint,

  status public.ai_run_status
    not null default 'running',

  error_code text,

  safety_profile public.ai_safety_profile
    not null default 'adult',

  started_at timestamptz not null default now(),
  completed_at timestamptz,

  created_at timestamptz not null default now(),

  constraint ai_runs_id_user_unique
    unique (id, user_id),

  constraint ai_runs_nonnegative_usage
    check (
      (input_tokens is null or input_tokens >= 0)
      and (output_tokens is null or output_tokens >= 0)
      and (cost_microusd is null or cost_microusd >= 0)
    ),

  constraint ai_runs_valid_completion
    check (
      (status = 'running' and completed_at is null)
      or
      (status <> 'running' and completed_at is not null)
    )
);

create index ai_runs_user_created_idx
on public.ai_runs (user_id, created_at desc);

create index ai_runs_user_purpose_idx
on public.ai_runs (user_id, purpose, created_at desc);

alter table public.ai_runs
enable row level security;

create policy "Users can view their own AI runs"
on public.ai_runs
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.ai_runs
from anon, authenticated;

grant select on public.ai_runs
to authenticated;

-- AI runs are created and updated by trusted server operations.

-- ---------------------------------------------------------
-- 3. CONVERSATIONS
-- ---------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  context_type public.conversation_context_type
    not null default 'general',

  discovery_session_id uuid,

  title text,

  retain_until timestamptz,

  archived_at timestamptz,
  deleted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint conversations_id_user_unique
    unique (id, user_id),

  constraint conversations_discovery_owner_fk
    foreign key (discovery_session_id, user_id)
    references public.discovery_sessions(id, user_id)
    on delete restrict,

  constraint conversations_context_reference_check
    check (
      (context_type = 'discovery' and discovery_session_id is not null)
      or
      (context_type <> 'discovery' and discovery_session_id is null)
    )
);

create index conversations_user_created_idx
on public.conversations (user_id, created_at desc);

create index conversations_user_active_idx
on public.conversations (user_id, updated_at desc)
where deleted_at is null;

create trigger conversations_updated_at
before update on public.conversations
for each row
execute function private.set_updated_at();

alter table public.conversations
enable row level security;

create policy "Users can view their own conversations"
on public.conversations
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own conversations"
on public.conversations
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own conversations"
on public.conversations
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.conversations
from anon, authenticated;

grant select, insert
on public.conversations
to authenticated;

grant update (
  title,
  archived_at,
  deleted_at
)
on public.conversations
to authenticated;

-- Users can create conversations and manage their own
-- titles, archive status and soft-delete status.
-- Context, ownership and discovery-session links cannot
-- be changed by authenticated browser clients.
-- Hard deletion is not permitted to authenticated users.

-- ---------------------------------------------------------
-- 4. MESSAGES
-- ---------------------------------------------------------

create table public.messages (
  id uuid primary key default gen_random_uuid(),

  conversation_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  role public.message_role not null,

  parts jsonb not null default '[]'::jsonb,

  run_id uuid,

  created_at timestamptz not null default now(),

  constraint messages_conversation_owner_fk
    foreign key (conversation_id, user_id)
    references public.conversations(id, user_id)
    on delete restrict,

  constraint messages_run_owner_fk
    foreign key (run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint messages_parts_array
    check (jsonb_typeof(parts) = 'array')
);

create index messages_conversation_created_idx
on public.messages (conversation_id, created_at);

create index messages_user_created_idx
on public.messages (user_id, created_at desc);

create index messages_run_idx
on public.messages (run_id)
where run_id is not null;

alter table public.messages
enable row level security;

create policy "Users can view their own messages"
on public.messages
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can submit their own user messages"
on public.messages
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and role = 'user'
  and run_id is null
);

revoke all on public.messages
from anon, authenticated;

grant select on public.messages
to authenticated;

grant insert (
  conversation_id,
  user_id,
  role,
  parts
)
on public.messages
to authenticated;

-- Assistant, system and tool messages are written by
-- trusted server-side AI operations.
-- Authenticated users cannot edit or delete messages.

-- ---------------------------------------------------------
-- 5. STRUCTURED AI OUTPUTS
-- ---------------------------------------------------------

create table public.ai_outputs (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  run_id uuid not null,

  output_type text not null,

  content jsonb not null,

  is_saved boolean not null default false,

  title text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_outputs_id_user_unique
    unique (id, user_id),

  constraint ai_outputs_run_owner_fk
    foreign key (run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint ai_outputs_type_not_empty
    check (length(trim(output_type)) > 0)
);

create index ai_outputs_user_created_idx
on public.ai_outputs (user_id, created_at desc);

create index ai_outputs_user_saved_idx
on public.ai_outputs (user_id, created_at desc)
where is_saved = true;

create index ai_outputs_run_idx
on public.ai_outputs (run_id);

create trigger ai_outputs_updated_at
before update on public.ai_outputs
for each row
execute function private.set_updated_at();

alter table public.ai_outputs
enable row level security;

create policy "Users can view their own AI outputs"
on public.ai_outputs
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can update their own output bookmarks"
on public.ai_outputs
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.ai_outputs
from anon, authenticated;

grant select on public.ai_outputs
to authenticated;

grant update (is_saved, title)
on public.ai_outputs
to authenticated;

-- Output creation and content changes are server-controlled.
-- Users can only save or rename their own outputs.

-- ---------------------------------------------------------
-- 6. TABLE COMMENTS
-- ---------------------------------------------------------

comment on table public.ai_runs is
  'Server-managed records of AI model invocations and usage metadata.';

comment on table public.conversations is
  'Private user-owned AI conversations.';

comment on table public.messages is
  'Append-only conversation messages with server-controlled AI roles.';

comment on table public.ai_outputs is
  'Structured AI-generated artefacts with user-controlled save status and title.';

commit;

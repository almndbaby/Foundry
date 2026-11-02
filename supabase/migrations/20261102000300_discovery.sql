-- =========================================================
-- FOUNDRY: MIGRATION 0003 — PERSONAL DISCOVERY
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.discovery_session_status as enum (
  'in_progress',
  'completed',
  'abandoned'
);

create type public.discovery_answer_type as enum (
  'free_text',
  'single_choice',
  'multi_choice',
  'scale'
);

create type public.discovery_audience as enum (
  'adult',
  'young_entrepreneur',
  'all'
);

create type public.discovery_category as enum (
  'skills',
  'experience',
  'interests',
  'resources',
  'constraints',
  'goals',
  'values'
);

create type public.attribute_category as enum (
  'skill',
  'experience',
  'interest',
  'resource',
  'constraint',
  'goal',
  'value'
);

create type public.attribute_provenance as enum (
  'user_stated',
  'ai_inferred'
);

create type public.attribute_review_status as enum (
  'unreviewed',
  'confirmed',
  'corrected',
  'rejected'
);

create type public.discovery_profile_status as enum (
  'draft',
  'reviewed',
  'superseded'
);

-- ---------------------------------------------------------
-- 2. DISCOVERY QUESTION BANK
-- ---------------------------------------------------------

create table public.discovery_questions (
  id uuid primary key default gen_random_uuid(),

  key text not null,
  version integer not null default 1,

  prompt text not null,
  help_text text,

  answer_type public.discovery_answer_type not null,

  options jsonb not null default '[]'::jsonb,

  audience public.discovery_audience
    not null default 'all',

  category public.discovery_category not null,

  position integer not null default 0,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint discovery_questions_key_version_unique
    unique (key, version),

  constraint discovery_questions_options_array
    check (jsonb_typeof(options) = 'array'),

  constraint discovery_questions_positive_version
    check (version > 0)
);

create index discovery_questions_active_position_idx
on public.discovery_questions (
  is_active,
  audience,
  position
);

create trigger discovery_questions_updated_at
before update on public.discovery_questions
for each row
execute function private.set_updated_at();

alter table public.discovery_questions
enable row level security;

create policy "Authenticated users can read active questions"
on public.discovery_questions
for select
to authenticated
using (is_active = true);

revoke all on public.discovery_questions
from anon, authenticated;

grant select on public.discovery_questions
to authenticated;

-- ---------------------------------------------------------
-- 3. DISCOVERY SESSIONS
-- ---------------------------------------------------------

create table public.discovery_sessions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  status public.discovery_session_status
    not null default 'in_progress',

  question_set_version integer
    not null default 1,

  started_at timestamptz
    not null default now(),

  completed_at timestamptz,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint discovery_sessions_id_user_unique
    unique (id, user_id),

  constraint discovery_sessions_valid_completion
    check (
      (status = 'completed' and completed_at is not null)
      or
      (status <> 'completed' and completed_at is null)
    )
);

create index discovery_sessions_user_created_idx
on public.discovery_sessions (user_id, created_at desc);

create trigger discovery_sessions_updated_at
before update on public.discovery_sessions
for each row
execute function private.set_updated_at();

alter table public.discovery_sessions
enable row level security;

create policy "Users can view their own discovery sessions"
on public.discovery_sessions
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own discovery sessions"
on public.discovery_sessions
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own discovery sessions"
on public.discovery_sessions
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.discovery_sessions
from anon, authenticated;

grant select, insert, update
on public.discovery_sessions
to authenticated;

-- ---------------------------------------------------------
-- 4. DISCOVERY ANSWERS
-- ---------------------------------------------------------

create table public.discovery_answers (
  id uuid primary key default gen_random_uuid(),

  session_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  question_id uuid not null
    references public.discovery_questions(id) on delete restrict,

  answer_text text,
  answer_value jsonb,

  answered_at timestamptz not null default now(),
  edited_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint discovery_answers_session_owner_fk
    foreign key (session_id, user_id)
    references public.discovery_sessions(id, user_id)
    on delete restrict,

  constraint discovery_answers_one_per_question
    unique (session_id, question_id),

  constraint discovery_answers_has_answer
    check (
      answer_text is not null
      or answer_value is not null
    )
);

create index discovery_answers_user_idx
on public.discovery_answers (user_id);

create index discovery_answers_question_idx
on public.discovery_answers (question_id);

create trigger discovery_answers_updated_at
before update on public.discovery_answers
for each row
execute function private.set_updated_at();

alter table public.discovery_answers
enable row level security;

create policy "Users can view their own discovery answers"
on public.discovery_answers
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own discovery answers"
on public.discovery_answers
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own discovery answers"
on public.discovery_answers
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.discovery_answers
from anon, authenticated;

grant select, insert, update
on public.discovery_answers
to authenticated;

-- ---------------------------------------------------------
-- 5. PROFILE ATTRIBUTES
-- ---------------------------------------------------------

create table public.profile_attributes (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  category public.attribute_category not null,

  label text not null,
  detail text,

  provenance public.attribute_provenance
    not null,

  review_status public.attribute_review_status
    not null default 'unreviewed',

  confidence numeric(3,2),

  source_answer_id uuid,

  generated_by_run_id uuid,

  corrected_from_id uuid,

  superseded_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profile_attributes_id_user_unique
    unique (id, user_id),

  constraint profile_attributes_source_answer_fk
    foreign key (source_answer_id, user_id)
    references public.discovery_answers(id, user_id)
    on delete restrict,

  constraint profile_attributes_corrected_from_fk
    foreign key (corrected_from_id, user_id)
    references public.profile_attributes(id, user_id)
    on delete restrict,

  constraint profile_attributes_confidence_range
    check (
      confidence is null
      or (confidence >= 0 and confidence <= 1)
    ),

  constraint profile_attributes_provenance_check
    check (
      (provenance = 'user_stated' and confidence is null)
      or
      (
        provenance = 'ai_inferred'
        and confidence is not null
        and generated_by_run_id is not null
      )
    )
);

create index profile_attributes_user_category_idx
on public.profile_attributes (user_id, category);

create index profile_attributes_user_review_idx
on public.profile_attributes (user_id, review_status);

create trigger profile_attributes_updated_at
before update on public.profile_attributes
for each row
execute function private.set_updated_at();

alter table public.profile_attributes
enable row level security;

create policy "Users can view their own profile attributes"
on public.profile_attributes
for select
to authenticated
using ((select auth.uid()) = user_id);

-- Attribute creation and AI inference are server-controlled.
-- Authenticated users can review their attributes, but cannot
-- create arbitrary AI-inferred claims through the browser.

revoke all on public.profile_attributes
from anon, authenticated;

grant select on public.profile_attributes
to authenticated;

grant update (review_status)
on public.profile_attributes
to authenticated;

create policy "Users can review their own profile attributes"
on public.profile_attributes
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------
-- 6. DISCOVERY PROFILE SNAPSHOTS
-- ---------------------------------------------------------

create table public.discovery_profiles (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  version integer not null,

  summary text,

  generated_by_run_id uuid,

  status public.discovery_profile_status
    not null default 'draft',

  reviewed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint discovery_profiles_id_user_unique
    unique (id, user_id),

  constraint discovery_profiles_user_version_unique
    unique (user_id, version),

  constraint discovery_profiles_positive_version
    check (version > 0)
);

create index discovery_profiles_user_created_idx
on public.discovery_profiles (user_id, created_at desc);

create trigger discovery_profiles_updated_at
before update on public.discovery_profiles
for each row
execute function private.set_updated_at();

alter table public.discovery_profiles
enable row level security;

create policy "Users can view their own discovery profiles"
on public.discovery_profiles
for select
to authenticated
using ((select auth.uid()) = user_id);

-- Profile snapshots are generated and updated by trusted
-- server-side application operations.

revoke all on public.discovery_profiles
from anon, authenticated;

grant select on public.discovery_profiles
to authenticated;

-- ---------------------------------------------------------
-- 7. DISCOVERY PROFILE ATTRIBUTE LINKS
-- ---------------------------------------------------------

create table public.discovery_profile_attributes (
  profile_id uuid not null,
  attribute_id uuid not null,
  user_id uuid not null,

  created_at timestamptz not null default now(),

  primary key (profile_id, attribute_id),

  constraint discovery_profile_attributes_profile_fk
    foreign key (profile_id, user_id)
    references public.discovery_profiles(id, user_id)
    on delete restrict,

  constraint discovery_profile_attributes_attribute_fk
    foreign key (attribute_id, user_id)
    references public.profile_attributes(id, user_id)
    on delete restrict
);

create index discovery_profile_attributes_attribute_idx
on public.discovery_profile_attributes (attribute_id);

alter table public.discovery_profile_attributes
enable row level security;

create policy "Users can view their own profile attribute links"
on public.discovery_profile_attributes
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.discovery_profile_attributes
from anon, authenticated;

grant select on public.discovery_profile_attributes
to authenticated;

-- ---------------------------------------------------------
-- 8. FINAL COMMENTS
-- ---------------------------------------------------------

comment on table public.discovery_questions is
  'Versioned reference question bank for Foundry discovery journeys.';

comment on table public.discovery_sessions is
  'A user-owned personal discovery journey.';

comment on table public.discovery_answers is
  'User-provided answers to discovery questions.';

comment on table public.profile_attributes is
  'User profile claims with explicit provenance and review status.';

comment on table public.discovery_profiles is
  'Versioned snapshots of a users generated discovery profile.';

commit;

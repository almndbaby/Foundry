-- =========================================================
-- FOUNDRY: MIGRATION 0006 — BUSINESS PROJECTS
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.project_stage as enum (
  'concept',
  'validation',
  'planning',
  'building',
  'launching',
  'operating',
  'growing',
  'paused',
  'archived'
);

create type public.offering_kind as enum (
  'product',
  'service',
  'digital_product',
  'subscription'
);

create type public.pricing_model as enum (
  'one_off',
  'recurring',
  'hourly',
  'tiered',
  'usage'
);

create type public.offering_status as enum (
  'idea',
  'validating',
  'active',
  'retired'
);

create type public.estimate_basis as enum (
  'verified_evidence',
  'estimate',
  'hypothesis'
);

create type public.business_plan_status as enum (
  'draft',
  'in_review',
  'final'
);

create type public.content_provenance as enum (
  'ai_draft',
  'user_written',
  'ai_draft_user_edited'
);

create type public.strategy_kind as enum (
  'marketing',
  'sales'
);

create type public.launch_status as enum (
  'planning',
  'ready',
  'launched',
  'postponed'
);

create type public.milestone_category as enum (
  'research',
  'planning',
  'legal',
  'product',
  'branding',
  'marketing',
  'sales',
  'launch',
  'growth'
);

create type public.milestone_status as enum (
  'todo',
  'in_progress',
  'done',
  'skipped'
);

-- ---------------------------------------------------------
-- 2. PROJECTS
-- ---------------------------------------------------------

create table public.projects (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  opportunity_id uuid,

  name text not null,
  tagline text,

  stage public.project_stage
    not null default 'concept',

  deleted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint projects_id_user_unique
    unique (id, user_id),

  constraint projects_opportunity_owner_fk
    foreign key (opportunity_id, user_id)
    references public.opportunities(id, user_id)
    on delete set null (opportunity_id),

  constraint projects_name_not_empty
    check (length(trim(name)) > 0)
);

create index projects_user_stage_idx
on public.projects (user_id, stage);

create index projects_user_created_idx
on public.projects (user_id, created_at desc);

create index projects_opportunity_idx
on public.projects (opportunity_id)
where opportunity_id is not null;

create trigger projects_updated_at
before update on public.projects
for each row
execute function private.set_updated_at();

alter table public.projects enable row level security;

create policy "Users can view their own projects"
on public.projects
for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own projects"
on public.projects
for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update their own projects"
on public.projects
for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.projects from anon, authenticated;

grant select, insert, update
on public.projects to authenticated;

grant delete on public.projects to authenticated;

-- ---------------------------------------------------------
-- 3. BUSINESS MODELS
-- ---------------------------------------------------------

create table public.business_models (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  value_proposition text,

  revenue_streams jsonb not null default '[]'::jsonb,
  cost_structure jsonb not null default '[]'::jsonb,
  channels jsonb not null default '[]'::jsonb,
  key_resources jsonb not null default '[]'::jsonb,
  key_partners jsonb not null default '[]'::jsonb,

  unfair_advantage text,

  version integer not null,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint business_models_id_user_unique
    unique (id, user_id),

  constraint business_models_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint business_models_version_positive
    check (version > 0),

  constraint business_models_project_version_unique
    unique (project_id, version),

  constraint business_models_json_arrays
    check (
      jsonb_typeof(revenue_streams) = 'array'
      and jsonb_typeof(cost_structure) = 'array'
      and jsonb_typeof(channels) = 'array'
      and jsonb_typeof(key_resources) = 'array'
      and jsonb_typeof(key_partners) = 'array'
    )
);

create unique index business_models_one_current_idx
on public.business_models (project_id)
where is_current = true;

create index business_models_user_project_idx
on public.business_models (user_id, project_id);

create trigger business_models_updated_at
before update on public.business_models
for each row
execute function private.set_updated_at();

alter table public.business_models enable row level security;

create policy "Users can manage their own business models"
on public.business_models
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.business_models from anon, authenticated;

grant select, insert, update, delete
on public.business_models to authenticated;

-- ---------------------------------------------------------
-- 4. OFFERINGS
-- ---------------------------------------------------------

create table public.offerings (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  kind public.offering_kind not null,

  name text not null,
  description text,

  pricing_model public.pricing_model,

  price_amount_minor bigint,
  unit_cost_minor bigint,
  currency char(3),

  status public.offering_status
    not null default 'idea',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint offerings_id_user_unique
    unique (id, user_id),

  constraint offerings_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint offerings_name_not_empty
    check (length(trim(name)) > 0),

  constraint offerings_price_nonnegative
    check (
      (price_amount_minor is null or price_amount_minor >= 0)
      and (unit_cost_minor is null or unit_cost_minor >= 0)
    ),

  constraint offerings_currency_format
    check (
      currency is null
      or currency ~ '^[A-Z]{3}$'
    )
);

create index offerings_user_project_idx
on public.offerings (user_id, project_id);

create index offerings_project_status_idx
on public.offerings (project_id, status);

create trigger offerings_updated_at
before update on public.offerings
for each row
execute function private.set_updated_at();

alter table public.offerings enable row level security;

create policy "Users can manage their own offerings"
on public.offerings
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.offerings from anon, authenticated;

grant select, insert, update, delete
on public.offerings to authenticated;

-- ---------------------------------------------------------
-- 5. CUSTOMER SEGMENTS
-- ---------------------------------------------------------

create table public.customer_segments (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  name text not null,
  description text,

  needs jsonb not null default '[]'::jsonb,
  characteristics jsonb not null default '{}'::jsonb,

  estimated_size numeric,
  size_basis public.estimate_basis,

  is_primary boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_segments_id_user_unique
    unique (id, user_id),

  constraint customer_segments_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint customer_segments_name_not_empty
    check (length(trim(name)) > 0),

  constraint customer_segments_size_nonnegative
    check (estimated_size is null or estimated_size >= 0),

  constraint customer_segments_needs_array
    check (jsonb_typeof(needs) = 'array'),

  constraint customer_segments_characteristics_object
    check (jsonb_typeof(characteristics) = 'object')
);

create index customer_segments_user_project_idx
on public.customer_segments (user_id, project_id);

create unique index customer_segments_one_primary_idx
on public.customer_segments (project_id)
where is_primary = true;

create trigger customer_segments_updated_at
before update on public.customer_segments
for each row
execute function private.set_updated_at();

alter table public.customer_segments enable row level security;

create policy "Users can manage their own customer segments"
on public.customer_segments
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.customer_segments from anon, authenticated;

grant select, insert, update, delete
on public.customer_segments to authenticated;

-- ---------------------------------------------------------
-- 6. OFFERING SEGMENTS
-- ---------------------------------------------------------

create table public.offering_segments (
  offering_id uuid not null,
  segment_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  created_at timestamptz not null default now(),

  primary key (offering_id, segment_id),

  constraint offering_segments_offering_owner_fk
    foreign key (offering_id, user_id)
    references public.offerings(id, user_id)
    on delete restrict,

  constraint offering_segments_segment_owner_fk
    foreign key (segment_id, user_id)
    references public.customer_segments(id, user_id)
    on delete restrict
);

create index offering_segments_segment_idx
on public.offering_segments (segment_id);

alter table public.offering_segments enable row level security;

create policy "Users can manage their own offering segments"
on public.offering_segments
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.offering_segments from anon, authenticated;

grant select, insert, update, delete
on public.offering_segments to authenticated;

-- ---------------------------------------------------------
-- 7. BUSINESS PLANS
-- ---------------------------------------------------------

create table public.business_plans (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  title text not null,

  status public.business_plan_status
    not null default 'draft',

  version integer not null,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint business_plans_id_user_unique
    unique (id, user_id),

  constraint business_plans_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint business_plans_version_positive
    check (version > 0),

  constraint business_plans_project_version_unique
    unique (project_id, version),

  constraint business_plans_title_not_empty
    check (length(trim(title)) > 0)
);

create unique index business_plans_one_current_idx
on public.business_plans (project_id)
where is_current = true;

create index business_plans_user_project_idx
on public.business_plans (user_id, project_id);

create trigger business_plans_updated_at
before update on public.business_plans
for each row
execute function private.set_updated_at();

alter table public.business_plans enable row level security;

create policy "Users can manage their own business plans"
on public.business_plans
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.business_plans from anon, authenticated;

grant select, insert, update, delete
on public.business_plans to authenticated;

-- ---------------------------------------------------------
-- 8. BUSINESS PLAN SECTIONS
-- ---------------------------------------------------------

create table public.business_plan_sections (
  id uuid primary key default gen_random_uuid(),

  plan_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  section_key text not null,
  position integer not null default 0,

  content_md text not null default '',

  generated_by_run_id uuid,

  last_edited_by uuid not null,

  provenance public.content_provenance
    not null default 'user_written',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint business_plan_sections_id_user_unique
    unique (id, user_id),

  constraint business_plan_sections_plan_owner_fk
    foreign key (plan_id, user_id)
    references public.business_plans(id, user_id)
    on delete restrict,

  constraint business_plan_sections_run_owner_fk
    foreign key (generated_by_run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint business_plan_sections_editor_owner_fk
    foreign key (last_edited_by)
    references public.profiles(id)
    on delete restrict,

  constraint business_plan_sections_editor_matches_owner
    check (last_edited_by = user_id),

  constraint business_plan_sections_key_not_empty
    check (length(trim(section_key)) > 0),

  constraint business_plan_sections_position_nonnegative
    check (position >= 0),

  constraint business_plan_sections_provenance_check
    check (
      (
        provenance = 'user_written'
        and generated_by_run_id is null
      )
      or
      (
        provenance in ('ai_draft', 'ai_draft_user_edited')
        and generated_by_run_id is not null
      )
    ),

  constraint business_plan_sections_plan_key_unique
    unique (plan_id, section_key)
);

create index business_plan_sections_user_plan_idx
on public.business_plan_sections (user_id, plan_id);

create trigger business_plan_sections_updated_at
before update on public.business_plan_sections
for each row
execute function private.set_updated_at();

alter table public.business_plan_sections enable row level security;

create policy "Users can manage their own business plan sections"
on public.business_plan_sections
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.business_plan_sections from anon, authenticated;

grant select, insert, update, delete
on public.business_plan_sections to authenticated;

-- ---------------------------------------------------------
-- 9. BRAND PROFILES
-- ---------------------------------------------------------

create table public.brand_profiles (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  brand_name text,
  name_candidates jsonb not null default '[]'::jsonb,

  positioning_statement text,
  mission text,

  voice_and_tone jsonb not null default '{}'::jsonb,
  values jsonb not null default '[]'::jsonb,
  visual_identity jsonb not null default '{}'::jsonb,

  logo_path text,

  version integer not null,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint brand_profiles_id_user_unique
    unique (id, user_id),

  constraint brand_profiles_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint brand_profiles_version_positive
    check (version > 0),

  constraint brand_profiles_project_version_unique
    unique (project_id, version),

  constraint brand_profiles_name_candidates_array
    check (jsonb_typeof(name_candidates) = 'array'),

  constraint brand_profiles_voice_object
    check (jsonb_typeof(voice_and_tone) = 'object'),

  constraint brand_profiles_values_array
    check (jsonb_typeof(values) = 'array'),

  constraint brand_profiles_visual_identity_object
    check (jsonb_typeof(visual_identity) = 'object')
);

create unique index brand_profiles_one_current_idx
on public.brand_profiles (project_id)
where is_current = true;

create index brand_profiles_user_project_idx
on public.brand_profiles (user_id, project_id);

create trigger brand_profiles_updated_at
before update on public.brand_profiles
for each row
execute function private.set_updated_at();

alter table public.brand_profiles enable row level security;

create policy "Users can manage their own brand profiles"
on public.brand_profiles
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.brand_profiles from anon, authenticated;

grant select, insert, update, delete
on public.brand_profiles to authenticated;

-- ---------------------------------------------------------
-- 10. GO-TO-MARKET STRATEGIES
-- ---------------------------------------------------------

create table public.go_to_market_strategies (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  kind public.strategy_kind not null,

  objectives jsonb not null default '[]'::jsonb,
  channels jsonb not null default '[]'::jsonb,
  messaging jsonb not null default '{}'::jsonb,
  tactics jsonb not null default '[]'::jsonb,

  budget_minor bigint,

  kpis jsonb not null default '[]'::jsonb,

  version integer not null,
  is_current boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint go_to_market_id_user_unique
    unique (id, user_id),

  constraint go_to_market_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint go_to_market_version_positive
    check (version > 0),

  constraint go_to_market_project_kind_version_unique
    unique (project_id, kind, version),

  constraint go_to_market_budget_nonnegative
    check (budget_minor is null or budget_minor >= 0),

  constraint go_to_market_objectives_array
    check (jsonb_typeof(objectives) = 'array'),

  constraint go_to_market_channels_array
    check (jsonb_typeof(channels) = 'array'),

  constraint go_to_market_messaging_object
    check (jsonb_typeof(messaging) = 'object'),

  constraint go_to_market_tactics_array
    check (jsonb_typeof(tactics) = 'array'),

  constraint go_to_market_kpis_array
    check (jsonb_typeof(kpis) = 'array')
);

create unique index go_to_market_one_current_per_kind_idx
on public.go_to_market_strategies (project_id, kind)
where is_current = true;

create index go_to_market_user_project_idx
on public.go_to_market_strategies (user_id, project_id);

create trigger go_to_market_updated_at
before update on public.go_to_market_strategies
for each row
execute function private.set_updated_at();

alter table public.go_to_market_strategies enable row level security;

create policy "Users can manage their own go to market strategies"
on public.go_to_market_strategies
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.go_to_market_strategies from anon, authenticated;

grant select, insert, update, delete
on public.go_to_market_strategies to authenticated;

-- ---------------------------------------------------------
-- 11. LAUNCH PLANS
-- ---------------------------------------------------------

create table public.launch_plans (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  target_launch_date date,

  status public.launch_status
    not null default 'planning',

  launched_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint launch_plans_id_project_owner_unique
    unique (id, project_id, user_id),

  constraint launch_plans_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict
);

create index launch_plans_user_project_idx
on public.launch_plans (user_id, project_id);

create trigger launch_plans_updated_at
before update on public.launch_plans
for each row
execute function private.set_updated_at();

alter table public.launch_plans enable row level security;

create policy "Users can manage their own launch plans"
on public.launch_plans
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.launch_plans from anon, authenticated;

grant select, insert, update, delete
on public.launch_plans to authenticated;

-- ---------------------------------------------------------
-- 12. MILESTONES
-- ---------------------------------------------------------

create table public.milestones (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  launch_plan_id uuid,

  title text not null,
  description text,

  category public.milestone_category not null,

  status public.milestone_status
    not null default 'todo',

  due_date date,
  completed_at timestamptz,

  position integer not null default 0,

  shareable_with_guardian boolean
    not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint milestones_id_user_unique
    unique (id, user_id),

  constraint milestones_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint milestones_launch_plan_owner_fk
    foreign key (launch_plan_id, project_id, user_id)
    references public.launch_plans(id, project_id, user_id)
    on delete restrict,

  constraint milestones_title_not_empty
    check (length(trim(title)) > 0),

  constraint milestones_position_nonnegative
    check (position >= 0),

  constraint milestones_completion_check
    check (
      (status = 'done' and completed_at is not null)
      or
      (status <> 'done' and completed_at is null)
    )
);

create index milestones_user_project_idx
on public.milestones (user_id, project_id);

create index milestones_project_status_idx
on public.milestones (project_id, status);

create index milestones_due_date_idx
on public.milestones (user_id, due_date)
where due_date is not null;

create trigger milestones_updated_at
before update on public.milestones
for each row
execute function private.set_updated_at();

alter table public.milestones enable row level security;

create policy "Users can manage their own milestones"
on public.milestones
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.milestones from anon, authenticated;

grant select, insert, update, delete
on public.milestones to authenticated;

-- ---------------------------------------------------------
-- 13. PROJECT ACTIVITY
-- ---------------------------------------------------------

create table public.project_activity (
  id uuid primary key default gen_random_uuid(),

  project_id uuid not null,
  user_id uuid not null
    references public.profiles(id) on delete restrict,

  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,

  occurred_at timestamptz not null default now(),

  constraint project_activity_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint project_activity_event_not_empty
    check (length(trim(event_type)) > 0),

  constraint project_activity_metadata_object
    check (jsonb_typeof(metadata) = 'object')
);

create index project_activity_user_project_idx
on public.project_activity (user_id, project_id, occurred_at desc);

alter table public.project_activity enable row level security;

create policy "Users can view their own project activity"
on public.project_activity
for select to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.project_activity from anon, authenticated;

grant select on public.project_activity to authenticated;

-- Activity is append-only and written by trusted server
-- operations. Authenticated clients cannot insert, update
-- or delete activity records.

-- ---------------------------------------------------------
-- 14. TABLE COMMENTS
-- ---------------------------------------------------------

comment on table public.projects is
  'Single-owner business projects developed from selected opportunities.';

comment on table public.business_models is
  'Versioned business models for each project.';

comment on table public.offerings is
  'Products and services offered by a business project.';

comment on table public.customer_segments is
  'Target customer personas and market segments, not real customer records.';

comment on table public.business_plans is
  'Versioned business plans for each project.';

comment on table public.business_plan_sections is
  'Editable business plan sections with AI provenance.';

comment on table public.brand_profiles is
  'Versioned brand identity and positioning profiles.';

comment on table public.go_to_market_strategies is
  'Versioned marketing and sales strategies.';

comment on table public.launch_plans is
  'Launch schedules and launch status for business projects.';

comment on table public.milestones is
  'Project progress milestones and tasks.';

comment on table public.project_activity is
  'Append-only project activity history.';

commit;

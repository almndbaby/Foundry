-- =========================================================
-- FOUNDRY: MIGRATION 0005 — OPPORTUNITIES
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.opportunity_business_type as enum (
  'product',
  'service',
  'digital',
  'hybrid'
);

create type public.opportunity_origin as enum (
  'ai_generated',
  'user_created'
);

create type public.opportunity_status as enum (
  'suggested',
  'shortlisted',
  'dismissed',
  'selected',
  'archived'
);

create type public.assessment_confidence as enum (
  'low',
  'medium',
  'high'
);

create type public.assessment_dimension_type as enum (
  'demand',
  'competition',
  'differentiation',
  'pricing',
  'profitability',
  'feasibility',
  'personal_fit',
  'regulatory',
  'startup_cost'
);

create type public.evidence_basis as enum (
  'verified_evidence',
  'estimate',
  'hypothesis'
);

create type public.research_source_type as enum (
  'government_statistic',
  'industry_report',
  'news',
  'competitor_site',
  'marketplace_listing',
  'academic',
  'user_provided',
  'other'
);

create type public.research_reliability as enum (
  'high',
  'medium',
  'low',
  'unknown'
);

create type public.evidence_type as enum (
  'verified_fact',
  'estimate',
  'hypothesis',
  'user_reported'
);

-- ---------------------------------------------------------
-- 2. OPPORTUNITIES
-- ---------------------------------------------------------

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  title text not null,
  summary text,

  industry text,

  business_type public.opportunity_business_type
    not null,

  origin public.opportunity_origin
    not null,

  status public.opportunity_status
    not null default 'suggested',

  generated_by_run_id uuid,
  discovery_profile_id uuid,

  created_at timestamptz not null default now(),
  constraint assessment_dimensions_id_user_unique
    unique (id, user_id),
  updated_at timestamptz not null default now(),

  constraint opportunities_id_user_unique
    unique (id, user_id),

  constraint opportunities_ai_run_owner_fk
    foreign key (generated_by_run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint opportunities_profile_owner_fk
    foreign key (discovery_profile_id, user_id)
    references public.discovery_profiles(id, user_id)
    on delete restrict,

  constraint opportunities_origin_provenance_check
    check (
      (
        origin = 'ai_generated'
        and generated_by_run_id is not null
      )
      or
      (
        origin = 'user_created'
        and generated_by_run_id is null
      )
    ),

  constraint opportunities_title_not_empty
    check (length(trim(title)) > 0)
);

create index opportunities_user_status_idx
on public.opportunities (user_id, status);

create index opportunities_user_created_idx
on public.opportunities (user_id, created_at desc);

create index opportunities_discovery_profile_idx
on public.opportunities (discovery_profile_id)
where discovery_profile_id is not null;

create trigger opportunities_updated_at
before update on public.opportunities
for each row
execute function private.set_updated_at();

alter table public.opportunities
enable row level security;

create policy "Users can view their own opportunities"
on public.opportunities
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create their own opportunities"
on public.opportunities
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and origin = 'user_created'
  and generated_by_run_id is null
);

create policy "Users can update their own opportunities"
on public.opportunities
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on public.opportunities
from anon, authenticated;

grant select on public.opportunities
to authenticated;

grant insert (
  user_id,
  title,
  summary,
  industry,
  business_type,
  origin,
  status,
  discovery_profile_id
)
on public.opportunities
to authenticated;

grant update (
  title,
  summary,
  industry,
  business_type,
  status
)
on public.opportunities
to authenticated;

-- AI-generated opportunities are created by trusted
-- server-side operations. Users can create their own
-- opportunities and manage their own opportunity details.

-- ---------------------------------------------------------
-- 3. OPPORTUNITY ASSESSMENTS
-- ---------------------------------------------------------

create table public.opportunity_assessments (
  id uuid primary key default gen_random_uuid(),

  opportunity_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  methodology_version text not null,

  overall_score numeric(5,2),

  overall_confidence public.assessment_confidence,

  generated_by_run_id uuid not null,

  is_current boolean not null default true,

  created_at timestamptz not null default now(),

  constraint opportunity_assessments_id_user_unique
    unique (id, user_id),

  constraint opportunity_assessments_opportunity_owner_fk
    foreign key (opportunity_id, user_id)
    references public.opportunities(id, user_id)
    on delete restrict,

  constraint opportunity_assessments_run_owner_fk
    foreign key (generated_by_run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint opportunity_assessments_score_range
    check (
      overall_score is null
      or (overall_score >= 0 and overall_score <= 100)
    ),

  constraint opportunity_assessments_methodology_not_empty
    check (length(trim(methodology_version)) > 0)
);

create index opportunity_assessments_user_idx
on public.opportunity_assessments (user_id, created_at desc);

create index opportunity_assessments_opportunity_idx
on public.opportunity_assessments (opportunity_id, created_at desc);

create unique index opportunity_assessments_one_current_idx
on public.opportunity_assessments (opportunity_id)
where is_current = true;

alter table public.opportunity_assessments
enable row level security;

create policy "Users can view their own opportunity assessments"
on public.opportunity_assessments
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.opportunity_assessments
from anon, authenticated;

grant select on public.opportunity_assessments
to authenticated;

-- Assessments are generated and maintained by trusted
-- server-side AI operations.

-- ---------------------------------------------------------
-- 4. ASSESSMENT DIMENSIONS
-- ---------------------------------------------------------

create table public.assessment_dimensions (
  id uuid primary key default gen_random_uuid(),

  assessment_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  dimension public.assessment_dimension_type
    not null,

  score numeric(5,2) not null,

  confidence public.assessment_confidence
    not null,

  basis public.evidence_basis not null,

  rationale text,

  created_at timestamptz not null default now(),

  constraint assessment_dimensions_assessment_owner_fk
    foreign key (assessment_id, user_id)
    references public.opportunity_assessments(id, user_id)
    on delete restrict,

  constraint assessment_dimensions_score_range
    check (score >= 0 and score <= 100),

  constraint assessment_dimensions_unique
    unique (assessment_id, dimension)
);

create index assessment_dimensions_user_idx
on public.assessment_dimensions (user_id);

alter table public.assessment_dimensions
enable row level security;

create policy "Users can view their own assessment dimensions"
on public.assessment_dimensions
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.assessment_dimensions
from anon, authenticated;

grant select on public.assessment_dimensions
to authenticated;

-- Assessment dimensions are server-generated and read-only
-- to authenticated browser clients.

-- ---------------------------------------------------------
-- 5. RESEARCH SOURCES
-- ---------------------------------------------------------

create table public.research_sources (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  url text not null,
  url_hash text not null,

  title text,
  publisher text,
  published_at timestamptz,

  retrieved_at timestamptz
    not null default now(),

  source_type public.research_source_type
    not null default 'other',

  reliability public.research_reliability
    not null default 'unknown',

  snapshot_path text,

  created_at timestamptz not null default now(),

  constraint research_sources_id_user_unique
    unique (id, user_id),

  constraint research_sources_user_url_hash_unique
    unique (user_id, url_hash),

  constraint research_sources_url_not_empty
    check (length(trim(url)) > 0),

  constraint research_sources_hash_not_empty
    check (length(trim(url_hash)) > 0)
);

create index research_sources_user_retrieved_idx
on public.research_sources (user_id, retrieved_at desc);

create index research_sources_user_type_idx
on public.research_sources (user_id, source_type);

alter table public.research_sources
enable row level security;

create policy "Users can view their own research sources"
on public.research_sources
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.research_sources
from anon, authenticated;

grant select on public.research_sources
to authenticated;

-- Sources are collected, validated and stored by trusted
-- server-side research operations.

-- ---------------------------------------------------------
-- 6. EVIDENCE ITEMS
-- ---------------------------------------------------------

create table public.evidence_items (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  opportunity_id uuid not null,

  source_id uuid,

  claim text not null,

  evidence_type public.evidence_type not null,

  value_numeric numeric,
  value_unit text,

  confidence public.assessment_confidence
    not null,

  generated_by_run_id uuid,

  created_at timestamptz not null default now(),

  constraint evidence_items_id_user_unique
    unique (id, user_id),

  constraint evidence_items_opportunity_owner_fk
    foreign key (opportunity_id, user_id)
    references public.opportunities(id, user_id)
    on delete restrict,

  constraint evidence_items_source_owner_fk
    foreign key (source_id, user_id)
    references public.research_sources(id, user_id)
    on delete restrict,

  constraint evidence_items_run_owner_fk
    foreign key (generated_by_run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint evidence_items_claim_not_empty
    check (length(trim(claim)) > 0),

  constraint evidence_items_verified_source_required
    check (
      evidence_type <> 'verified_fact'
      or source_id is not null
    )
);

create index evidence_items_user_created_idx
on public.evidence_items (user_id, created_at desc);

create index evidence_items_opportunity_idx
on public.evidence_items (opportunity_id);

create index evidence_items_source_idx
on public.evidence_items (source_id)
where source_id is not null;

alter table public.evidence_items
enable row level security;

create policy "Users can view their own evidence items"
on public.evidence_items
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.evidence_items
from anon, authenticated;

grant select on public.evidence_items
to authenticated;

-- Evidence is created and maintained by trusted
-- server-side research and assessment operations.

-- ---------------------------------------------------------
-- 7. ASSESSMENT DIMENSION EVIDENCE LINKS
-- ---------------------------------------------------------

create table public.assessment_dimension_evidence (
  dimension_id uuid not null,

  evidence_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  created_at timestamptz not null default now(),

  primary key (dimension_id, evidence_id),

  constraint assessment_dimension_evidence_dimension_owner_fk
    foreign key (dimension_id, user_id)
    references public.assessment_dimensions(id, user_id)
    on delete restrict,

  constraint assessment_dimension_evidence_evidence_owner_fk
    foreign key (evidence_id, user_id)
    references public.evidence_items(id, user_id)
    on delete restrict
);

create index assessment_dimension_evidence_evidence_idx
on public.assessment_dimension_evidence (evidence_id);

alter table public.assessment_dimension_evidence
enable row level security;

create policy "Users can view their own assessment evidence links"
on public.assessment_dimension_evidence
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.assessment_dimension_evidence
from anon, authenticated;

grant select on public.assessment_dimension_evidence
to authenticated;

-- Links are created by trusted server-side operations.
-- Composite foreign keys ensure both linked records
-- belong to the same user.

-- ---------------------------------------------------------
-- 8. TABLE COMMENTS
-- ---------------------------------------------------------

comment on table public.opportunities is
  'User-owned business opportunities, generated by AI or created by the user.';

comment on table public.opportunity_assessments is
  'Versioned commercial assessments of business opportunities.';

comment on table public.assessment_dimensions is
  'Individual scored dimensions supporting an opportunity assessment.';

comment on table public.research_sources is
  'Per-user research sources used to support opportunity assessments.';

comment on table public.evidence_items is
  'Claims and supporting evidence linked to a users opportunity.';

comment on table public.assessment_dimension_evidence is
  'Links assessment dimensions to supporting evidence items.';

commit;

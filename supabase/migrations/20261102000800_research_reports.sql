-- =========================================================
-- FOUNDRY: MIGRATION 0008
-- RESEARCH REPORTS
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.research_report_status as enum (
  'draft',
  'generating',
  'completed',
  'failed',
  'archived'
);

create type public.research_section_kind as enum (
  'executive_summary',
  'market_overview',
  'customer_demand',
  'competitor_analysis',
  'pricing_analysis',
  'industry_trends',
  'regulatory_considerations',
  'risks',
  'recommendations',
  'other'
);

-- ---------------------------------------------------------
-- 2. SUPPORT COMPOSITE ASSESSMENT OWNERSHIP
-- ---------------------------------------------------------

alter table public.opportunity_assessments
add constraint opportunity_assessments_id_opportunity_user_unique
unique (id, opportunity_id, user_id);

-- ---------------------------------------------------------
-- 3. RESEARCH REPORTS
-- ---------------------------------------------------------

create table public.research_reports (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  opportunity_id uuid not null,

  assessment_id uuid,

  generated_by_run_id uuid,

  title text not null,

  summary text,

  status public.research_report_status
    not null default 'draft',

  methodology_version text not null,

  version integer not null default 1,

  is_current boolean not null default true,

  started_at timestamptz,

  completed_at timestamptz,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint research_reports_id_user_unique
    unique (id, user_id),

  constraint research_reports_opportunity_owner_fk
    foreign key (opportunity_id, user_id)
    references public.opportunities(id, user_id)
    on delete restrict,

  constraint research_reports_assessment_owner_fk
    foreign key (assessment_id, opportunity_id, user_id)
    references public.opportunity_assessments(
      id,
      opportunity_id,
      user_id
    )
    on delete restrict,

  constraint research_reports_run_owner_fk
    foreign key (generated_by_run_id, user_id)
    references public.ai_runs(id, user_id)
    on delete restrict,

  constraint research_reports_title_not_empty
    check (length(trim(title)) > 0),

  constraint research_reports_methodology_not_empty
    check (length(trim(methodology_version)) > 0),

  constraint research_reports_version_positive
    check (version > 0),

    constraint research_reports_completion_check
    check (
      (status = 'completed' and completed_at is not null)
      or
      (status <> 'completed' and completed_at is null)
    )
);

create unique index research_reports_one_current_idx
on public.research_reports (opportunity_id)
where is_current = true;

create unique index research_reports_version_idx
on public.research_reports (opportunity_id, user_id, version);

create index research_reports_user_opportunity_idx
on public.research_reports (user_id, opportunity_id);

create index research_reports_user_created_idx
on public.research_reports (user_id, created_at desc);

create trigger research_reports_updated_at
before update on public.research_reports
for each row
execute function private.set_updated_at();

alter table public.research_reports
enable row level security;

create policy "Users can view their own research reports"
on public.research_reports
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.research_reports
from anon, authenticated;

grant select on public.research_reports
to authenticated;

-- Reports are created and maintained by trusted
-- server-side research operations.

-- ---------------------------------------------------------
-- 4. RESEARCH REPORT SECTIONS
-- ---------------------------------------------------------

create table public.research_report_sections (
  id uuid primary key default gen_random_uuid(),

  report_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  section_kind public.research_section_kind
    not null,

  heading text not null,

  content_md text not null default '',

  position integer not null default 0,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint research_report_sections_report_owner_fk
    foreign key (report_id, user_id)
    references public.research_reports(id, user_id)
    on delete restrict,

  constraint research_report_sections_position_nonnegative
    check (position >= 0),

  constraint research_report_sections_heading_not_empty
    check (length(trim(heading)) > 0),

  constraint research_report_sections_unique_kind
    unique (report_id, section_kind)
);

create index research_report_sections_report_position_idx
on public.research_report_sections (report_id, position);

create trigger research_report_sections_updated_at
before update on public.research_report_sections
for each row
execute function private.set_updated_at();

alter table public.research_report_sections
enable row level security;

create policy "Users can view their own research report sections"
on public.research_report_sections
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.research_report_sections
from anon, authenticated;

grant select on public.research_report_sections
to authenticated;

-- Sections are written by trusted research operations.

-- ---------------------------------------------------------
-- 5. RESEARCH REPORT SOURCES
-- ---------------------------------------------------------

create table public.research_report_sources (
  report_id uuid not null,

  source_id uuid not null,

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  relevance_note text,

  position integer not null default 0,

  created_at timestamptz
    not null default now(),

  primary key (report_id, source_id),

  constraint research_report_sources_report_owner_fk
    foreign key (report_id, user_id)
    references public.research_reports(id, user_id)
    on delete restrict,

  constraint research_report_sources_source_owner_fk
    foreign key (source_id, user_id)
    references public.research_sources(id, user_id)
    on delete restrict,

  constraint research_report_sources_position_nonnegative
    check (position >= 0)
);

create index research_report_sources_source_idx
on public.research_report_sources (source_id);

alter table public.research_report_sources
enable row level security;

create policy "Users can view their own research report sources"
on public.research_report_sources
for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.research_report_sources
from anon, authenticated;

grant select on public.research_report_sources
to authenticated;

-- Source associations are maintained by trusted
-- server-side research operations.

-- ---------------------------------------------------------
-- 6. TABLE COMMENTS
-- ---------------------------------------------------------

comment on table public.research_reports is
  'Versioned research reports supporting business opportunity validation.';

comment on table public.research_report_sections is
  'Structured sections of a research report.';

comment on table public.research_report_sources is
  'Links research reports to their supporting source records.';

commit;

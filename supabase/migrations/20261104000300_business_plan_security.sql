-- =========================================================
-- FOUNDRY: MIGRATION 0012
-- BUSINESS PLAN SECURITY HARDENING
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. REMOVE BROAD TABLE PERMISSIONS
-- ---------------------------------------------------------

revoke insert, update
on public.business_plan_sections
from authenticated;

-- ---------------------------------------------------------
-- 2. ALLOW CONTROLLED USER INSERTS
-- ---------------------------------------------------------

grant insert (
  plan_id,
  user_id,
  section_key,
  position,
  content_md,
  last_edited_by
)
on public.business_plan_sections
to authenticated;

-- ---------------------------------------------------------
-- 3. ALLOW CONTROLLED USER UPDATES
-- ---------------------------------------------------------

grant update (
  section_key,
  position,
  content_md,
  last_edited_by
)
on public.business_plan_sections
to authenticated;

-- ---------------------------------------------------------
-- 4. SERVER-CONTROLLED PROVENANCE
-- ---------------------------------------------------------

-- Authenticated users cannot directly change:
--
-- generated_by_run_id
-- provenance
-- created_at
-- updated_at
--
-- These fields are managed by trusted server-side
-- business plan generation and editing operations.

comment on column public.business_plan_sections.generated_by_run_id is
  'Server-controlled reference to the AI run responsible for generating this section.';

comment on column public.business_plan_sections.provenance is
  'Server-controlled record of whether content was user-written or AI-generated.';

commit;

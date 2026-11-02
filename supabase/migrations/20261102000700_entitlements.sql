-- =========================================================
-- FOUNDRY: MIGRATION 0007
-- FREE ENTITLEMENTS AND USAGE TRACKING
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ENUM TYPES
-- ---------------------------------------------------------

create type public.plan_audience_enum as enum (
  'adult',
  'young_entrepreneur',
  'all'
);

create type public.billing_interval_enum as enum (
  'free',
  'monthly',
  'yearly'
);

create type public.feature_kind_enum as enum (
  'access',
  'metered'
);

create type public.usage_reset_period_enum as enum (
  'never',
  'daily',
  'monthly'
);

create type public.entitlement_source_enum as enum (
  'pathway_default',
  'manual',
  'promotion'
);

-- ---------------------------------------------------------
-- 2. PLANS
-- ---------------------------------------------------------

create table public.plans (
  id uuid primary key default gen_random_uuid(),

  code text not null unique,
  name text not null,
  description text,

  audience public.plan_audience_enum
    not null default 'adult',

  billing_interval public.billing_interval_enum
    not null default 'free',

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint plans_code_format
    check (code ~ '^[a-z0-9_]+$')
);

comment on table public.plans is
  'Available Foundry entitlement plans. Billing and payment processing are not implemented in v0.';

create trigger plans_updated_at
before update on public.plans
for each row
execute function private.set_updated_at();

-- ---------------------------------------------------------
-- 3. FEATURES
-- ---------------------------------------------------------

create table public.features (
  id uuid primary key default gen_random_uuid(),

  key text not null unique,
  name text not null,
  description text,

  kind public.feature_kind_enum
    not null,

  reset_period public.usage_reset_period_enum
    not null default 'never',

  is_active boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  constraint features_key_format
    check (key ~ '^[a-z0-9_]+$')
);

comment on table public.features is
  'Registry of Foundry product features and measurable capabilities.';

-- ---------------------------------------------------------
-- 4. PLAN FEATURES
-- ---------------------------------------------------------

create table public.plan_features (
  plan_id uuid not null
    references public.plans(id) on delete restrict,

  feature_id uuid not null
    references public.features(id) on delete restrict,

  -- NULL means unlimited.
  limit_value integer,

  is_enabled boolean
    not null default true,

  created_at timestamptz
    not null default now(),

  primary key (plan_id, feature_id),

  constraint plan_features_limit_nonnegative
    check (limit_value is null or limit_value >= 0)
);

comment on table public.plan_features is
  'Defines which features each plan includes and their usage limits. A NULL limit means unlimited.';

-- ---------------------------------------------------------
-- 5. USER ENTITLEMENTS
-- ---------------------------------------------------------

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  plan_id uuid
    references public.plans(id) on delete restrict,

  feature_id uuid not null
    references public.features(id) on delete restrict,

  source public.entitlement_source_enum
    not null default 'pathway_default',

  source_ref text,

  valid_from timestamptz
    not null default now(),

  valid_until timestamptz,

  created_at timestamptz
    not null default now(),

  constraint entitlements_validity
    check (valid_until is null or valid_until > valid_from),

  constraint entitlements_user_feature_start_unique
    unique (user_id, feature_id, valid_from)
);

create index entitlements_user_active_idx
on public.entitlements (user_id, valid_until);

comment on table public.entitlements is
  'Records the features granted to individual users and the period for which they are valid.';

-- ---------------------------------------------------------
-- 6. USAGE COUNTERS
-- ---------------------------------------------------------

create table public.usage_counters (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  feature_id uuid not null
    references public.features(id) on delete restrict,

  period_start timestamptz not null,
  period_end timestamptz,

  usage_count bigint
    not null default 0,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint usage_counters_nonnegative
    check (usage_count >= 0),

  constraint usage_counters_period_valid
    check (period_end is null or period_end > period_start),

  constraint usage_counters_unique_period
    unique (user_id, feature_id, period_start)
);

create index usage_counters_user_feature_idx
on public.usage_counters (user_id, feature_id);

create trigger usage_counters_updated_at
before update on public.usage_counters
for each row
execute function private.set_updated_at();

comment on table public.usage_counters is
  'Aggregated usage totals for each user, feature and usage period.';

-- ---------------------------------------------------------
-- 7. USAGE EVENTS
-- ---------------------------------------------------------

create table public.usage_events (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  feature_id uuid not null
    references public.features(id) on delete restrict,

  quantity integer
    not null default 1,

  idempotency_key text unique,

  metadata jsonb
    not null default '{}'::jsonb,

  occurred_at timestamptz
    not null default now(),

  constraint usage_events_quantity_positive
    check (quantity > 0),

  constraint usage_events_metadata_object
    check (jsonb_typeof(metadata) = 'object')
);

create index usage_events_user_feature_time_idx
on public.usage_events (user_id, feature_id, occurred_at desc);

comment on table public.usage_events is
  'Append-only records of individual feature usage events.';

-- ---------------------------------------------------------
-- 8. SEED THE FREE ADULT PLAN
-- ---------------------------------------------------------

insert into public.plans (
  code,
  name,
  description,
  audience,
  billing_interval,
  is_active
)
values (
  'free',
  'Foundry Free',
  'The default free Foundry plan.',
  'adult',
  'free',
  true
)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  audience = excluded.audience,
  billing_interval = excluded.billing_interval,
  is_active = excluded.is_active;

-- ---------------------------------------------------------
-- 9. SEED INITIAL FEATURES
-- ---------------------------------------------------------

insert into public.features (
  key,
  name,
  description,
  kind,
  reset_period,
  is_active
)
values
(
  'projects',
  'Business Projects',
  'Create and manage business projects.',
  'metered',
  'never',
  true
),
(
  'ai_messages',
  'AI Messages',
  'Send messages to Foundry AI.',
  'metered',
  'monthly',
  true
),
(
  'opportunity_generation',
  'Opportunity Generation',
  'Generate business opportunities.',
  'metered',
  'monthly',
  true
),
(
  'research_runs',
  'Research Runs',
  'Run research and opportunity assessments.',
  'metered',
  'monthly',
  true
),
(
  'business_plan_generation',
  'Business Plan Generation',
  'Generate business plans.',
  'metered',
  'monthly',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  kind = excluded.kind,
  reset_period = excluded.reset_period,
  is_active = excluded.is_active;

-- ---------------------------------------------------------
-- 10. CONNECT FEATURES TO THE FREE PLAN
-- ---------------------------------------------------------

-- NULL limits mean unlimited during the initial development
-- phase. Limits can be introduced later without changing
-- the entitlement structure.

insert into public.plan_features (
  plan_id,
  feature_id,
  limit_value,
  is_enabled
)
select
  p.id,
  f.id,
  null,
  true
from public.plans p
cross join public.features f
where
  p.code = 'free'
  and f.key in (
    'projects',
    'ai_messages',
    'opportunity_generation',
    'research_runs',
    'business_plan_generation'
  )
on conflict (plan_id, feature_id) do update
set
  limit_value = excluded.limit_value,
  is_enabled = excluded.is_enabled;

-- ---------------------------------------------------------
-- 11. PROVISION DEFAULT ENTITLEMENTS
-- ---------------------------------------------------------

create or replace function private.provision_free_entitlements()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin

  -- The initial free plan is for adult accounts only.
  -- Young entrepreneur accounts are deliberately excluded.

  if new.pathway <> 'adult' then
    return new;
  end if;

  insert into public.entitlements (
    user_id,
    plan_id,
    feature_id,
    source,
    valid_from
  )
  select
    new.id,
    p.id,
    pf.feature_id,
    'pathway_default',
    new.created_at
  from public.plans p
  join public.plan_features pf
    on pf.plan_id = p.id
  join public.features f
    on f.id = pf.feature_id
  where
    p.code = 'free'
    and p.is_active = true
    and pf.is_enabled = true
    and f.is_active = true
  on conflict (
    user_id,
    feature_id,
    valid_from
  ) do nothing;

  return new;

end;
$function$;

revoke all on function private.provision_free_entitlements()
from public, anon, authenticated;

drop trigger if exists profiles_provision_entitlements
on public.profiles;

create trigger profiles_provision_entitlements
after insert on public.profiles
for each row
execute function private.provision_free_entitlements();

-- ---------------------------------------------------------
-- 12. BACKFILL EXISTING ADULT PROFILES
-- ---------------------------------------------------------

insert into public.entitlements (
  user_id,
  plan_id,
  feature_id,
  source,
  valid_from
)
select
  p.id,
  plan.id,
  pf.feature_id,
  'pathway_default',
  p.created_at
from public.profiles p
join public.plans plan
  on plan.code = 'free'
  and plan.is_active = true
join public.plan_features pf
  on pf.plan_id = plan.id
  and pf.is_enabled = true
join public.features f
  on f.id = pf.feature_id
  and f.is_active = true
where
  p.pathway = 'adult'
on conflict (
  user_id,
  feature_id,
  valid_from
) do nothing;

-- ---------------------------------------------------------
-- 13. ROW LEVEL SECURITY
-- ---------------------------------------------------------

alter table public.plans
enable row level security;

alter table public.features
enable row level security;

alter table public.plan_features
enable row level security;

alter table public.entitlements
enable row level security;

alter table public.usage_counters
enable row level security;

alter table public.usage_events
enable row level security;

-- Active plans are visible to authenticated users.

create policy "Authenticated users can view active plans"
on public.plans
for select
to authenticated
using (is_active = true);

-- Active features are visible to authenticated users.

create policy "Authenticated users can view active features"
on public.features
for select
to authenticated
using (is_active = true);

-- Users can view feature allocations for active plans
-- and active features.

create policy "Authenticated users can view active plan features"
on public.plan_features
for select
to authenticated
using (
  is_enabled = true
  and exists (
    select 1
    from public.plans p
    join public.features f
      on f.id = plan_features.feature_id
    where
      p.id = plan_features.plan_id
      and p.is_active = true
      and f.is_active = true
  )
);

-- Users can only read their own entitlements.

create policy "Users can view their own entitlements"
on public.entitlements
for select
to authenticated
using (
  (select auth.uid()) = user_id
);

-- Users can only read their own usage counters.

create policy "Users can view their own usage counters"
on public.usage_counters
for select
to authenticated
using (
  (select auth.uid()) = user_id
);

-- Users can only read their own usage events.

create policy "Users can view their own usage events"
on public.usage_events
for select
to authenticated
using (
  (select auth.uid()) = user_id
);

-- ---------------------------------------------------------
-- 14. DATABASE PRIVILEGES
-- ---------------------------------------------------------

revoke all on public.plans
from anon, authenticated;

revoke all on public.features
from anon, authenticated;

revoke all on public.plan_features
from anon, authenticated;

revoke all on public.entitlements
from anon, authenticated;

revoke all on public.usage_counters
from anon, authenticated;

revoke all on public.usage_events
from anon, authenticated;

grant select on public.plans
to authenticated;

grant select on public.features
to authenticated;

grant select on public.plan_features
to authenticated;

grant select on public.entitlements
to authenticated;

grant select on public.usage_counters
to authenticated;

grant select on public.usage_events
to authenticated;

commit;

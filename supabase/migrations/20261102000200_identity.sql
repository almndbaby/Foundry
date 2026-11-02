-- =========================================================
-- FOUNDRY: MIGRATION 0002 — IDENTITY AND USER ACCOUNTS
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. ACCOUNT TYPES
-- ---------------------------------------------------------

create type public.pathway_enum as enum (
  'adult',
  'young_entrepreneur'
);

create type public.account_status_enum as enum (
  'active',
  'restricted',
  'suspended',
  'pending_deletion'
);

-- ---------------------------------------------------------
-- 2. USER PROFILES
-- ---------------------------------------------------------

create table public.profiles (
  id uuid primary key
    references auth.users(id) on delete restrict,

  display_name text,

  pathway public.pathway_enum
    not null default 'adult',

  account_status public.account_status_enum
    not null default 'active',

  country_code char(2),

  locale text
    not null default 'en-US',

  timezone text,

  onboarding_completed_at timestamptz,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now()
);

comment on table public.profiles is
  'Foundry user profiles. Protected account fields are server-controlled.';

-- ---------------------------------------------------------
-- 3. USER SETTINGS
-- ---------------------------------------------------------

create table public.user_settings (
  user_id uuid primary key
    references public.profiles(id) on delete restrict,

  preferences jsonb
    not null default '{}'::jsonb,

  created_at timestamptz
    not null default now(),

  updated_at timestamptz
    not null default now(),

  constraint user_settings_preferences_object
    check (jsonb_typeof(preferences) = 'object')
);

-- ---------------------------------------------------------
-- 4. AUTOMATIC UPDATED_AT TIMESTAMPS
-- ---------------------------------------------------------

create trigger profiles_updated_at
before update on public.profiles
for each row
execute function private.set_updated_at();

create trigger user_settings_updated_at
before update on public.user_settings
for each row
execute function private.set_updated_at();

-- ---------------------------------------------------------
-- 5. AUTOMATIC ACCOUNT CREATION
-- ---------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin

  insert into public.profiles (
    id,
    display_name
  )
  values (
    new.id,
    nullif(
      pg_catalog.btrim(
        new.raw_user_meta_data ->> 'display_name'
      ),
      ''
    )
  );

  insert into public.user_settings (
    user_id
  )
  values (
    new.id
  );

  return new;

end;
$function$;

revoke all on function public.handle_new_user()
from public, anon, authenticated;

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- ---------------------------------------------------------
-- 6. SUPPORT EXISTING AUTH USERS
-- ---------------------------------------------------------

insert into public.profiles (
  id,
  display_name
)
select
  id,
  nullif(
    pg_catalog.btrim(
      raw_user_meta_data ->> 'display_name'
    ),
    ''
  )
from auth.users
on conflict (id) do nothing;

insert into public.user_settings (
  user_id
)
select id
from public.profiles
on conflict (user_id) do nothing;

-- ---------------------------------------------------------
-- 7. ROW LEVEL SECURITY
-- ---------------------------------------------------------

alter table public.profiles
enable row level security;

alter table public.user_settings
enable row level security;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using (
  (select auth.uid()) = id
);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using (
  (select auth.uid()) = id
)
with check (
  (select auth.uid()) = id
);

create policy "Users can view their own settings"
on public.user_settings
for select
to authenticated
using (
  (select auth.uid()) = user_id
);

create policy "Users can update their own settings"
on public.user_settings
for update
to authenticated
using (
  (select auth.uid()) = user_id
)
with check (
  (select auth.uid()) = user_id
);

-- ---------------------------------------------------------
-- 8. DATABASE PRIVILEGES
-- ---------------------------------------------------------

revoke all on public.profiles
from anon, authenticated;

revoke all on public.user_settings
from anon, authenticated;

grant select on public.profiles
to authenticated;

grant update (
  display_name,
  locale,
  timezone
)
on public.profiles
to authenticated;

grant select on public.user_settings
to authenticated;

grant update (
  preferences
)
on public.user_settings
to authenticated;

commit;

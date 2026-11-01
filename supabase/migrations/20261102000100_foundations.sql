-- Foundry: foundational database setup
-- Target: isolated development project (Supabase eu-west-2)
-- This migration intentionally creates no application tables.

begin;

-- Internal schema, not exposed through the Supabase Data API.
create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

-- Shared trigger helper for future tables.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

revoke all on function private.set_updated_at() from public;
revoke all on function private.set_updated_at() from anon;
revoke all on function private.set_updated_at() from authenticated;

commit;

-- =========================================================
-- FOUNDRY: MIGRATION 0009
-- PROJECT CONVERSATION LINKS
-- Target: Development database (London)
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1. PROJECT CONVERSATION LINKS
-- ---------------------------------------------------------

create table public.conversation_links (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id) on delete restrict,

  conversation_id uuid not null,

  project_id uuid not null,

  created_at timestamptz
    not null default now(),

  constraint conversation_links_conversation_owner_fk
    foreign key (conversation_id, user_id)
    references public.conversations(id, user_id)
    on delete restrict,

  constraint conversation_links_project_owner_fk
    foreign key (project_id, user_id)
    references public.projects(id, user_id)
    on delete restrict,

  constraint conversation_links_conversation_unique
    unique (conversation_id)
);

create index conversation_links_user_project_idx
on public.conversation_links (user_id, project_id);

create index conversation_links_project_idx
on public.conversation_links (project_id);

alter table public.conversation_links
enable row level security;

-- ---------------------------------------------------------
-- 2. ROW LEVEL SECURITY
-- ---------------------------------------------------------

create policy "Users can view their own conversation links"
on public.conversation_links
for select
to authenticated
using (
  (select auth.uid()) = user_id
);

create policy "Users can link their own conversations to projects"
on public.conversation_links
for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (
    select 1
    from public.conversations c
    where
      c.id = conversation_id
      and c.user_id = (select auth.uid())
      and c.deleted_at is null
  )
  and exists (
    select 1
    from public.projects p
    where
      p.id = project_id
      and p.user_id = (select auth.uid())
      and p.deleted_at is null
  )
);

create policy "Users can unlink their own conversations"
on public.conversation_links
for delete
to authenticated
using (
  (select auth.uid()) = user_id
);

-- ---------------------------------------------------------
-- 3. DATABASE PRIVILEGES
-- ---------------------------------------------------------

revoke all on public.conversation_links
from anon, authenticated;

grant select, insert, delete
on public.conversation_links
to authenticated;

-- Users can link and unlink their own conversations.
-- Ownership of both records is enforced by composite
-- foreign keys and row-level security.
-- A conversation can be linked to only one project.

-- ---------------------------------------------------------
-- 4. TABLE COMMENT
-- ---------------------------------------------------------

comment on table public.conversation_links is
  'Associates a private AI conversation with one user-owned business project.';

commit;

-- SSS Khatabook: initial Supabase/PostgreSQL authorization foundation.
-- Run only on a dedicated NEW project after review. Never run on production blindly.
-- auth.users is managed by Supabase Auth (phone OTP, email, Google).
create extension if not exists pgcrypto;

create table if not exists public.khata_workspaces (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('personal','business')),
 display_name text not null check (length(trim(display_name)) > 0),
 owner_user_id uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique (id, owner_user_id)
);
create table if not exists public.khata_memberships (
 workspace_id uuid not null references public.khata_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id),
 role text not null check (role in ('owner','admin','accountant','staff','viewer')),
 status text not null default 'active' check (status in ('active','suspended')),
 primary key (workspace_id,user_id)
);
create table if not exists public.khata_parties (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.khata_workspaces(id),
 name text not null check (length(trim(name)) > 0),
 unique (id,workspace_id)
);
create table if not exists public.khata_accounts (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.khata_workspaces(id),
 name text not null,
 opening_balance_paise bigint not null default 0,
 unique (id,workspace_id),
 unique (workspace_id,name)
);
create table if not exists public.khata_entries (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.khata_workspaces(id),
 account_id uuid not null,
 party_id uuid,
 kind text not null check (kind in ('income','expense','transfer_in','transfer_out')),
 amount_paise bigint not null check (amount_paise > 0),
 idempotency_key uuid not null,
 occurred_at timestamptz not null,
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id),
 unique(workspace_id,idempotency_key),
 foreign key (account_id,workspace_id) references public.khata_accounts(id,workspace_id),
 foreign key (party_id,workspace_id) references public.khata_parties(id,workspace_id)
);
create index if not exists khata_entries_workspace_time on public.khata_entries(workspace_id,occurred_at);

-- SECURITY DEFINER helper is narrowly scoped, search_path pinned and reads only memberships.
create or replace function public.khata_has_role(w uuid, allowed text[])
returns boolean language sql stable security definer
set search_path = ''
as $$
 select auth.uid() is not null and exists (
  select 1 from public.khata_memberships m
  where m.workspace_id = w and m.user_id = auth.uid()
    and m.status = 'active' and m.role = any(allowed)
 );
$$;
revoke all on function public.khata_has_role(uuid,text[]) from public;
grant execute on function public.khata_has_role(uuid,text[]) to authenticated;

alter table public.khata_workspaces enable row level security;
alter table public.khata_memberships enable row level security;
alter table public.khata_parties enable row level security;
alter table public.khata_accounts enable row level security;
alter table public.khata_entries enable row level security;

-- Deliberately no client INSERT/UPDATE/DELETE policies for workspaces/memberships:
-- creation, invitations, role changes, suspensions and owner transfer require trusted server RPCs.
create policy workspace_read on public.khata_workspaces for select to authenticated
 using (public.khata_has_role(id,array['owner','admin','accountant','staff','viewer']));
create policy membership_read on public.khata_memberships for select to authenticated
 using (public.khata_has_role(workspace_id,array['owner','admin']));
create policy party_read on public.khata_parties for select to authenticated
 using (public.khata_has_role(workspace_id,array['owner','admin','accountant','staff','viewer']));
create policy party_insert on public.khata_parties for insert to authenticated
 with check (public.khata_has_role(workspace_id,array['owner','admin','accountant','staff']));
create policy account_read on public.khata_accounts for select to authenticated
 using (public.khata_has_role(workspace_id,array['owner','admin','accountant','staff','viewer']));
-- Opening balance and account mutation require a separately audited server operation.
create policy entry_read on public.khata_entries for select to authenticated
 using (public.khata_has_role(workspace_id,array['owner','admin','accountant','staff','viewer']));
create policy entry_insert on public.khata_entries for insert to authenticated
 with check (public.khata_has_role(workspace_id,array['owner','admin','accountant','staff'])
   and created_by = auth.uid());
-- Entries immutable: corrections must be new audited reversal entries.

-- Explicit privileges complement RLS. No table mutations for anonymous users.
revoke all on public.khata_workspaces,public.khata_memberships,public.khata_parties,
 public.khata_accounts,public.khata_entries from anon,authenticated;
grant select on public.khata_workspaces,public.khata_memberships,
 public.khata_parties,public.khata_accounts,public.khata_entries to authenticated;
grant insert on public.khata_parties,public.khata_entries to authenticated;

-- Important: service_role bypasses RLS; never expose service key to mobile/web clients.
-- Missing: trusted workspace bootstrap, audit triggers, admin suspension enforcement,
-- server-side idempotent sync endpoint, 30-day signed lease and live PostgreSQL tests.

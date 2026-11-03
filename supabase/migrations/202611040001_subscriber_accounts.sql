-- Subscriber account management. Apply using a trusted Supabase migration.
-- Never expose service_role credentials to Flutter clients.
create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.subscriber_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id),
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  status text not null default 'active' check (status in ('active','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists subscriber_accounts_status_idx
  on public.subscriber_accounts(status);
create table if not exists public.subscriber_account_audit (
  id bigint generated always as identity primary key,
  account_id uuid not null references public.subscriber_accounts(id),
  actor_id uuid not null references auth.users(id),
  action text not null check (action in ('created','renamed','suspended','reactivated')),
  recorded_at timestamptz not null default now()
);
create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.platform_admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

alter table public.platform_admins enable row level security;
alter table public.subscriber_accounts enable row level security;
alter table public.subscriber_account_audit enable row level security;

-- platform_admins has no client policies; provision using privileged server tooling only.
drop policy if exists subscriber_accounts_read on public.subscriber_accounts;
create policy subscriber_accounts_read on public.subscriber_accounts
for select to authenticated using (
  owner_user_id = (select auth.uid()) or (select public.is_platform_admin())
);
drop policy if exists subscriber_accounts_admin_insert on public.subscriber_accounts;
create policy subscriber_accounts_admin_insert on public.subscriber_accounts
for insert to authenticated with check ((select public.is_platform_admin()));
drop policy if exists subscriber_accounts_admin_update on public.subscriber_accounts;
create policy subscriber_accounts_admin_update on public.subscriber_accounts
for update to authenticated
using ((select public.is_platform_admin()))
with check ((select public.is_platform_admin()));

-- Audit records are server-written, not client-written.
drop policy if exists subscriber_audit_admin_read on public.subscriber_account_audit;
create policy subscriber_audit_admin_read on public.subscriber_account_audit
for select to authenticated using ((select public.is_platform_admin()));

-- Restrict dangerous client-side mutations and protect the audit trail.
revoke all on public.platform_admins from anon, authenticated;
revoke all on public.subscriber_account_audit from anon, authenticated;
grant select on public.subscriber_account_audit to authenticated;
revoke all on public.subscriber_accounts from anon, authenticated;
grant select, insert on public.subscriber_accounts to authenticated;
grant update (display_name, status) on public.subscriber_accounts to authenticated;

-- Force auditing for mutations, including those made through a privileged API.
create or replace function public.audit_subscriber_account_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare action_name text;
begin
  if tg_op = 'INSERT' then
    action_name := 'created';
  elsif old.status is distinct from new.status then
    action_name := case when new.status = 'suspended' then 'suspended' else 'reactivated' end;
  elsif old.display_name is distinct from new.display_name then
    action_name := 'renamed';
  else
    return new;
  end if;
  insert into public.subscriber_account_audit(account_id,actor_id,action)
  values(new.id,coalesce((select auth.uid()),new.owner_user_id),action_name);
  return new;
end;
$$;
drop trigger if exists subscriber_account_audit_trigger on public.subscriber_accounts;
create trigger subscriber_account_audit_trigger
after insert or update on public.subscriber_accounts
for each row execute function public.audit_subscriber_account_change();

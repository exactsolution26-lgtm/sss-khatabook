-- Financial records are private to the subscriber owner, including against
-- platform admins. No super-admin bypass is granted for customer ledgers.
create or replace function public.owns_subscriber(tenant uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.subscriber_accounts
    where id = tenant and owner_user_id = (select auth.uid()));
$$;
create or replace function public.can_write_subscriber(tenant uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists(select 1 from public.subscriber_accounts
    where id = tenant and owner_user_id = (select auth.uid()) and status = 'active');
$$;
revoke all on function public.owns_subscriber(uuid) from public;
revoke all on function public.can_write_subscriber(uuid) from public;
grant execute on function public.owns_subscriber(uuid), public.can_write_subscriber(uuid) to authenticated;

create table public.parties (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.subscriber_accounts(id),
  name text not null check(length(btrim(name)) between 1 and 120),
  phone text check(phone is null or phone ~ '^[0-9+ ()-]{7,24}$'),
  opening_paise bigint not null default 0 check(abs(opening_paise::numeric) <= 9000000000000000),
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tenant_id,id)
);
create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.subscriber_accounts(id),
  party_id uuid not null,
  kind text not null check(kind in ('debit','credit')),
  amount_paise bigint not null check(amount_paise > 0 and amount_paise <= 9000000000000000),
  note text not null default '' check(length(note) <= 2000),
  occurred_at timestamptz not null,
  idempotency_key uuid not null,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(tenant_id,party_id) references public.parties(tenant_id,id),
  unique(tenant_id,idempotency_key)
);
create index ledger_entries_tenant_party_date_idx on public.ledger_entries(tenant_id,party_id,occurred_at,id);
create index parties_tenant_name_idx on public.parties(tenant_id,name);

create table public.financial_audit (
  id bigint generated always as identity primary key,
  tenant_id uuid not null references public.subscriber_accounts(id),
  record_id uuid not null,
  record_type text not null,
  actor_id uuid references auth.users(id),
  action text not null,
  recorded_at timestamptz not null default now()
);
create index financial_audit_tenant_date_idx on public.financial_audit(tenant_id,recorded_at);

create or replace function public.guard_financial_update()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.id <> old.id or new.tenant_id <> old.tenant_id or new.created_at <> old.created_at then
    raise exception 'Immutable financial identity';
  end if;
  if new.version <> old.version + 1 then
    raise exception 'Version conflict' using errcode = '40001';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create or replace function public.audit_financial_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.financial_audit(tenant_id,record_id,record_type,actor_id,action)
  values(new.tenant_id,new.id,tg_table_name,(select auth.uid()),tg_op);
  return new;
end;
$$;
create trigger parties_version_guard before update on public.parties
for each row execute function public.guard_financial_update();
create trigger ledger_version_guard before update on public.ledger_entries
for each row execute function public.guard_financial_update();
create trigger parties_audit after insert or update on public.parties
for each row execute function public.audit_financial_change();
create trigger ledger_audit after insert or update on public.ledger_entries
for each row execute function public.audit_financial_change();

alter table public.parties enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.financial_audit enable row level security;
create policy parties_read on public.parties for select to authenticated
using ((select public.owns_subscriber(tenant_id)));
create policy parties_insert on public.parties for insert to authenticated
with check ((select public.can_write_subscriber(tenant_id)) and version = 1);
create policy parties_update on public.parties for update to authenticated
using ((select public.can_write_subscriber(tenant_id)))
with check ((select public.can_write_subscriber(tenant_id)));
create policy ledger_read on public.ledger_entries for select to authenticated
using ((select public.owns_subscriber(tenant_id)));
create policy ledger_insert on public.ledger_entries for insert to authenticated
with check ((select public.can_write_subscriber(tenant_id)) and version = 1);
create policy ledger_update on public.ledger_entries for update to authenticated
using ((select public.can_write_subscriber(tenant_id)))
with check ((select public.can_write_subscriber(tenant_id)));
create policy financial_audit_read on public.financial_audit for select to authenticated
using ((select public.owns_subscriber(tenant_id)));
revoke all on public.parties, public.ledger_entries, public.financial_audit from anon, authenticated;
grant select, insert, update on public.parties, public.ledger_entries to authenticated;
grant select on public.financial_audit to authenticated;
-- No direct deletion; a separately reviewed retention/reversal workflow is needed.
revoke all on function public.guard_financial_update() from public;
revoke all on function public.audit_financial_change() from public;

-- Durable catalogue and isolated billing simulation. No live entitlement is issued here.
create table public.billing_plans (
  id text primary key,
  name text not null check (length(btrim(name)) between 1 and 80),
  price_paise integer not null check (price_paise between 0 and 100000000),
  billing_months integer not null check (billing_months between 1 and 12),
  active boolean not null default true,
  discount_kind text,
  discount_value integer,
  discount_start timestamptz,
  discount_end timestamptz,
  check (
    (discount_kind is null and discount_value is null and discount_start is null and discount_end is null)
    or (discount_kind is not null and discount_value is not null
      and discount_start is not null and discount_end is not null and discount_start < discount_end
      and ((discount_kind = 'percentage' and discount_value between 0 and 100)
        or (discount_kind = 'fixed_paise' and discount_value between 0 and price_paise)))
  )
);
insert into public.billing_plans(id, name, price_paise, billing_months)
values ('monthly', 'Monthly', 9900, 1);

create table public.billing_plan_audit (
  id bigint generated always as identity primary key,
  actor_id uuid not null references auth.users(id),
  plan_id text not null references public.billing_plans(id),
  previous jsonb not null,
  replacement jsonb not null,
  recorded_at timestamptz not null default now()
);

create table public.billing_test_orders (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.subscriber_accounts(id),
  request_id uuid not null,
  plan_id text not null references public.billing_plans(id),
  original_paise integer not null,
  discount_paise integer not null,
  amount_paise integer not null,
  billing_months integer not null,
  currency text not null default 'INR',
  status text not null default 'pending' check (status in ('pending','paid','failed')),
  created_at timestamptz not null default now(),
  settled_at timestamptz,
  unique (account_id, request_id)
);

create table public.billing_test_access (
  account_id uuid primary key references public.subscriber_accounts(id),
  valid_until timestamptz not null
);

alter table public.billing_plans enable row level security;
alter table public.billing_plan_audit enable row level security;
alter table public.billing_test_orders enable row level security;
alter table public.billing_test_access enable row level security;

revoke all on public.billing_plans, public.billing_plan_audit,
  public.billing_test_orders, public.billing_test_access from public, anon, authenticated;
grant select on public.billing_plans, public.billing_plan_audit,
  public.billing_test_orders, public.billing_test_access to authenticated;
grant update (name, price_paise, billing_months, active, discount_kind,
  discount_value, discount_start, discount_end) on public.billing_plans to authenticated;

create policy billing_catalogue_read on public.billing_plans for select to authenticated
using (active or (select public.is_platform_admin()));
create policy billing_catalogue_admin_update on public.billing_plans for update to authenticated
using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy billing_plan_audit_admin_read on public.billing_plan_audit for select to authenticated
using ((select public.is_platform_admin()));
create policy billing_test_orders_read on public.billing_test_orders for select to authenticated
using ((select public.is_platform_admin()) or exists (
  select 1 from public.subscriber_accounts a where a.id = account_id and a.owner_user_id = (select auth.uid())
));
create policy billing_test_access_read on public.billing_test_access for select to authenticated
using ((select public.is_platform_admin()) or exists (
  select 1 from public.subscriber_accounts a where a.id = account_id
    and a.owner_user_id = (select auth.uid()) and a.status = 'active'
));

create function public.audit_billing_plan()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old is distinct from new then
    insert into public.billing_plan_audit(actor_id, plan_id, previous, replacement)
    values ((select auth.uid()), new.id, to_jsonb(old), to_jsonb(new));
  end if;
  return new;
end
$$;
revoke all on function public.audit_billing_plan() from public, anon, authenticated;
create trigger audit_billing_plan after update on public.billing_plans
for each row execute function public.audit_billing_plan();

-- A checkout snapshot is priced and created server-side. Retrying a request
-- returns the same snapshot even when the catalogue changes afterwards.
create function public.create_billing_test_order(p_plan_id text, p_request_id uuid)
returns public.billing_test_orders
language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid;
  plan public.billing_plans;
  order_row public.billing_test_orders;
  savings integer := 0;
begin
  select id into tenant from public.subscriber_accounts
    where owner_user_id = (select auth.uid()) and status = 'active' for update;
  if tenant is null then
    raise exception using errcode = '42501', message = 'Active subscriber required';
  end if;
  select * into order_row from public.billing_test_orders
    where account_id = tenant and request_id = p_request_id;
  if found then
    if order_row.plan_id is distinct from p_plan_id then
      raise exception using errcode = '22023', message = 'Request ID already used for a different plan';
    end if;
    return order_row;
  end if;
  select * into strict plan from public.billing_plans where id = p_plan_id and active;
  if now() >= plan.discount_start and now() < plan.discount_end then
    savings := case plan.discount_kind when 'percentage'
      then (plan.price_paise::bigint * plan.discount_value / 100)::integer
      else plan.discount_value end;
  end if;
  insert into public.billing_test_orders(account_id, request_id, plan_id, original_paise,
    discount_paise, amount_paise, billing_months)
  values (tenant, p_request_id, plan.id, plan.price_paise, savings, plan.price_paise - savings, plan.billing_months)
  returning * into order_row;
  return order_row;
end
$$;
revoke all on function public.create_billing_test_order(text, uuid) from public, anon, authenticated;
grant execute on function public.create_billing_test_order(text, uuid) to authenticated;

-- Only a trusted server can settle a simulated payment. This function is not
-- a provider webhook or proof of payment. It writes only test-mode access.
create function public.settle_billing_test_order(
  p_order_id uuid, p_amount_paise integer, p_currency text, p_paid boolean
)
returns public.billing_test_orders
language plpgsql security definer set search_path = '' as $$
declare
  order_row public.billing_test_orders;
  tenant uuid;
  target_status text;
  settled timestamptz := now();
  months interval;
begin
  select account_id into strict tenant from public.billing_test_orders where id = p_order_id;
  perform 1 from public.subscriber_accounts where id = tenant for update;
  select * into strict order_row from public.billing_test_orders where id = p_order_id for update;
  if p_paid is null or order_row.amount_paise is distinct from p_amount_paise
    or order_row.currency is distinct from p_currency then
    raise exception using errcode = '22023', message = 'Settlement details do not match checkout';
  end if;
  target_status := case when p_paid then 'paid' else 'failed' end;
  if order_row.status = target_status then return order_row; end if;
  if order_row.status <> 'pending' then
    raise exception using errcode = '22023', message = 'Order is already settled';
  end if;
  update public.billing_test_orders set status = target_status, settled_at = settled
    where id = p_order_id returning * into order_row;
  if p_paid then
    months := make_interval(months => order_row.billing_months);
    insert into public.billing_test_access as existing_access(account_id, valid_until)
      values (tenant, ((settled at time zone 'UTC') + months) at time zone 'UTC')
    on conflict (account_id) do update set valid_until =
      ((greatest(existing_access.valid_until, settled) at time zone 'UTC') + months) at time zone 'UTC';
  end if;
  return order_row;
end
$$;
revoke all on function public.settle_billing_test_order(uuid, integer, text, boolean) from public, anon, authenticated;
grant execute on function public.settle_billing_test_order(uuid, integer, text, boolean) to service_role;

create function public.billing_test_revenue()
returns table (successful_payments bigint, collected_paise bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_platform_admin() then
    raise exception using errcode = '42501', message = 'Super Admin access required';
  end if;
  return query select count(*), coalesce(sum(amount_paise), 0)
    from public.billing_test_orders where status = 'paid';
end
$$;
revoke all on function public.billing_test_revenue() from public, anon, authenticated;
grant execute on function public.billing_test_revenue() to authenticated;

\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values
('00000000-0000-0000-0000-000000000001'),
('00000000-0000-0000-0000-000000000002'),
('00000000-0000-0000-0000-000000000003');
insert into public.platform_admins(user_id) values ('00000000-0000-0000-0000-000000000003');
insert into public.subscriber_accounts(id,owner_user_id,display_name) values
('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Tenant A'),
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','Tenant B');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare o public.billing_test_orders;
begin
  o := public.create_billing_test_order('monthly','40000000-0000-0000-0000-000000000001');
  if o.amount_paise <> 9900 or o.status <> 'pending' then raise exception 'Incorrect default quote'; end if;
  update public.billing_plans set price_paise = 1 where id = 'monthly';
  if found then raise exception 'Subscriber changed price'; end if;
  begin
    perform public.settle_billing_test_order(o.id,9900,'INR',true);
    raise exception 'Subscriber could settle payment';
  exception when insufficient_privilege then null; end;
  begin
    perform public.billing_test_revenue();
    raise exception 'Subscriber could read revenue';
  exception when insufficient_privilege then null; end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
update public.billing_plans set price_paise=12000, discount_kind='percentage', discount_value=25,
  discount_start=now()-interval '1 day', discount_end=now()+interval '1 day' where id='monthly';
do $$ begin
  if (select count(*) from public.billing_plan_audit) <> 1 then raise exception 'Plan update not audited'; end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare o public.billing_test_orders;
begin
  o := public.create_billing_test_order('monthly','40000000-0000-0000-0000-000000000001');
  if o.amount_paise <> 9900 then raise exception 'Snapshot changed on retry'; end if;
  o := public.create_billing_test_order('monthly','40000000-0000-0000-0000-000000000002');
  if o.original_paise <> 12000 or o.discount_paise <> 3000 or o.amount_paise <> 9000 then
    raise exception 'Discount calculated incorrectly';
  end if;
  perform public.create_billing_test_order('monthly','40000000-0000-0000-0000-000000000003');
end $$;
select id as first_order from public.billing_test_orders where request_id = '40000000-0000-0000-0000-000000000001' \gset
select id as second_order from public.billing_test_orders where request_id = '40000000-0000-0000-0000-000000000002' \gset
select id as failed_order from public.billing_test_orders where request_id = '40000000-0000-0000-0000-000000000003' \gset

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin
  if exists (select 1 from public.billing_test_orders) then raise exception 'Cross-subscriber order leak'; end if;
end $$;

set local role service_role;
select (public.settle_billing_test_order(:'failed_order',9000,'INR',false)).status;
select (public.settle_billing_test_order(:'first_order',9900,'INR',true)).status;
select (public.settle_billing_test_order(:'first_order',9900,'INR',true)).status;
select (public.settle_billing_test_order(:'second_order',9000,'INR',true)).status;

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if (select valid_until from public.billing_test_access) is distinct from
    ((((now() at time zone 'UTC') + interval '1 month') + interval '1 month') at time zone 'UTC') then
    raise exception 'Failure, duplicate settlement or renewal changed access incorrectly';
  end if;
  if (select count(*) from public.billing_test_orders where status = 'failed') <> 1 then
    raise exception 'Failed payment not recorded';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
  if not exists (select 1 from public.billing_test_revenue() where successful_payments=2 and collected_paise=18900) then
    raise exception 'Incorrect test revenue';
  end if;
end $$;
update public.subscriber_accounts set status='suspended'
where id='10000000-0000-0000-0000-000000000001';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if exists (select 1 from public.billing_test_access) then raise exception 'Suspended subscriber sees test entitlement'; end if;
  begin
    perform public.create_billing_test_order('monthly','40000000-0000-0000-0000-000000000004');
    raise exception 'Suspended account could start checkout';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

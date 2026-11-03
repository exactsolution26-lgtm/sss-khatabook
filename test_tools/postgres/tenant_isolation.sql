\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values
('00000000-0000-0000-0000-000000000001'),
('00000000-0000-0000-0000-000000000002'),
('00000000-0000-0000-0000-000000000003');
insert into public.platform_admins(user_id) values('00000000-0000-0000-0000-000000000003');
insert into public.subscriber_accounts(id,owner_user_id,display_name) values
('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Tenant A'),
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','Tenant B');
insert into public.parties(id,tenant_id,name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Party A'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Party B');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if (select count(*) from public.parties) <> 1 then raise exception 'Cross-tenant SELECT leak'; end if;
  if public.is_platform_admin() then raise exception 'Role escalation'; end if;
  begin
    insert into public.parties(tenant_id,name) values('10000000-0000-0000-0000-000000000002','Attack');
    raise exception 'Cross-tenant INSERT allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.platform_admins(user_id) values('00000000-0000-0000-0000-000000000001');
    raise exception 'Admin self-provision allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.financial_audit(tenant_id,record_id,record_type,action)
    values('10000000-0000-0000-0000-000000000001',gen_random_uuid(),'parties','forged');
    raise exception 'Audit forgery allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.ledger_entries(tenant_id,party_id,kind,amount_paise,occurred_at,idempotency_key)
    values('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','debit',100,now(),gen_random_uuid());
    raise exception 'Cross-tenant party link allowed';
  exception when foreign_key_violation then null; end;
end $$;
insert into public.ledger_entries(id,tenant_id,party_id,kind,amount_paise,occurred_at,idempotency_key)
values('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
'20000000-0000-0000-0000-000000000001','debit',12345,now(),'40000000-0000-0000-0000-000000000001');
do $$ begin
  begin
    insert into public.ledger_entries(tenant_id,party_id,kind,amount_paise,occurred_at,idempotency_key)
    values('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','debit',12345,now(),'40000000-0000-0000-0000-000000000001');
    raise exception 'Duplicate operation accepted';
  exception when unique_violation then null; end;
  begin
    update public.ledger_entries set note = 'stale writer' where id = '30000000-0000-0000-0000-000000000001';
    raise exception 'Stale version accepted';
  exception when serialization_failure then null; end;
end $$;
update public.ledger_entries set note = 'valid edit', version = version + 1
where id = '30000000-0000-0000-0000-000000000001' and version = 1;
do $$ begin
  if (select count(*) from public.financial_audit where record_id = '30000000-0000-0000-0000-000000000001') <> 2 then
    raise exception 'Financial audit missing';
  end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin
  if (select count(*) from public.ledger_entries) <> 0 then raise exception 'Ledger SELECT leak'; end if;
  update public.ledger_entries set note='attack', version=version+1 where id='30000000-0000-0000-0000-000000000001';
  if found then raise exception 'Cross-tenant UPDATE'; end if;
  if (select count(*) from public.financial_audit where record_id='30000000-0000-0000-0000-000000000001') <> 0 then raise exception 'Audit SELECT leak'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
  if not public.is_platform_admin() then raise exception 'Admin bootstrap broken'; end if;
  if (select count(*) from public.subscriber_accounts) <> 2 then raise exception 'Admin monitoring broken'; end if;
  if (select count(*) from public.ledger_entries) <> 0 or (select count(*) from public.parties) <> 0 then
    raise exception 'Platform admin silently read financial records';
  end if;
end $$;
reset role;
update public.subscriber_accounts set status='suspended' where id='10000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if public.can_write_subscriber('10000000-0000-0000-0000-000000000001') then raise exception 'Suspension bypass'; end if;
  if (select count(*) from public.ledger_entries) <> 1 then raise exception 'Suspension destroyed read recovery'; end if;
  begin
    insert into public.parties(tenant_id,name) values('10000000-0000-0000-0000-000000000001','Suspended write');
    raise exception 'Suspended write accepted';
  exception when insufficient_privilege then null; end;
end $$;
set local role anon;
do $$ begin
  begin
    perform * from public.ledger_entries;
    raise exception 'Anonymous ledger access';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
\echo 'PASS: PostgreSQL tenant roles, RLS, privilege escalation, audit, duplicates, version conflicts and suspension'

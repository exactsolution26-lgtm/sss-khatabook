\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values
('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002');
insert into public.subscriber_accounts(id, owner_user_id, display_name) values
('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','A'),
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','B');
insert into public.parties(id, tenant_id, name) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','A party'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','B party');

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$
declare
  a constant uuid := '10000000-0000-0000-0000-000000000001';
  party constant uuid := '20000000-0000-0000-0000-000000000001';
  entry constant uuid := '30000000-0000-0000-0000-000000000001';
  create_op constant uuid := '40000000-0000-0000-0000-000000000001';
  edit_op constant uuid := '40000000-0000-0000-0000-000000000002';
  stale_op constant uuid := '40000000-0000-0000-0000-000000000003';
  occurred constant timestamptz := '2026-11-11T00:00:00Z';
  initial jsonb;
  edited jsonb;
begin
  initial := public.apply_ledger_sync_operation(a,create_op,entry,0,party,'credit',9900,'original',occurred);
  edited := public.apply_ledger_sync_operation(a,edit_op,entry,1,party,'credit',10000,'edited',occurred);
  if initial->>'version' is distinct from '1' or edited->>'version' is distinct from '2' then
    raise exception 'Incorrect sync versions';
  end if;
  if public.apply_ledger_sync_operation(a,create_op,entry,0,party,'credit',9900,'original',occurred)
      is distinct from initial or
     public.apply_ledger_sync_operation(a,edit_op,entry,1,party,'credit',10000,'edited',occurred)
      is distinct from edited then
    raise exception 'Retry did not return original receipt';
  end if;
  if (select count(*) from public.financial_audit where record_id = entry) <> 2 then
    raise exception 'Duplicate request mutated the ledger';
  end if;
  begin
    perform public.apply_ledger_sync_operation(a,edit_op,entry,1,party,'credit',10001,'edited',occurred);
    raise exception 'Reused operation ID accepted different data';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.apply_ledger_sync_operation(a,stale_op,entry,1,party,'credit',1,'stale',occurred);
    raise exception 'Stale edit was applied';
  exception when serialization_failure then null; end;
  begin
    perform public.apply_ledger_sync_operation(a,stale_op,entry,2,
      '20000000-0000-0000-0000-000000000002','credit',1,'foreign party',occurred);
    raise exception 'Cross-tenant party link was applied';
  exception when foreign_key_violation then null; end;
  if (select note from public.ledger_entries where id = entry) is distinct from 'edited' then
    raise exception 'Rejected sync operation changed the entry';
  end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin
  begin
    perform public.apply_ledger_sync_operation('10000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',0,
      '20000000-0000-0000-0000-000000000001','credit',9900,'original','2026-11-11T00:00:00Z');
    raise exception 'Cross-tenant receipt exposed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.subscriber_accounts set status='suspended'
  where id='10000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  begin
    perform public.apply_ledger_sync_operation('10000000-0000-0000-0000-000000000001',
      '40000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001',2,
      '20000000-0000-0000-0000-000000000001','credit',12345,'suspended','2026-11-11T00:00:00Z');
    raise exception 'Suspended subscriber was allowed to sync';
  exception when insufficient_privilege then null; end;
end $$;
rollback;

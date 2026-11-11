-- Reconnect-safe writes for cloud ledger entries. Receipts are server-owned
-- and scoped to the authenticated subscriber and the queued operation ID.
create table public.ledger_sync_receipts (
  tenant_id uuid not null references public.subscriber_accounts(id),
  operation_id uuid not null,
  request jsonb not null,
  result jsonb,
  applied_at timestamptz not null default now(),
  primary key (tenant_id, operation_id)
);
alter table public.ledger_sync_receipts enable row level security;
revoke all on public.ledger_sync_receipts from public, anon, authenticated;

create function public.apply_ledger_sync_operation(
  p_tenant_id uuid,
  p_operation_id uuid,
  p_entry_id uuid,
  p_expected_version bigint,
  p_party_id uuid,
  p_kind text,
  p_amount_paise bigint,
  p_note text,
  p_occurred_at timestamptz
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  request_data jsonb;
  receipt public.ledger_sync_receipts;
  entry public.ledger_entries;
begin
  -- Hold the subscriber status stable through settlement of the queued write.
  perform 1 from public.subscriber_accounts
    where id = p_tenant_id and owner_user_id = (select auth.uid())
      and status = 'active' for share;
  if not found then
    raise exception using errcode = '42501', message = 'Active subscriber required';
  end if;
  if p_operation_id is null or p_entry_id is null or p_expected_version is null
      or p_expected_version < 0 then
    raise exception using errcode = '22023', message = 'Invalid sync identity or version';
  end if;
  request_data := jsonb_build_array(p_entry_id, p_expected_version, p_party_id,
    p_kind, p_amount_paise, p_note, extract(epoch from p_occurred_at));
  insert into public.ledger_sync_receipts(tenant_id, operation_id, request)
    values (p_tenant_id, p_operation_id, request_data)
    on conflict (tenant_id, operation_id) do nothing;
  if not found then
    select * into strict receipt from public.ledger_sync_receipts
      where tenant_id = p_tenant_id and operation_id = p_operation_id;
    if receipt.request is distinct from request_data then
      raise exception using errcode = '22023', message = 'Sync operation ID already used';
    end if;
    return receipt.result;
  end if;

  if p_expected_version = 0 then
    insert into public.ledger_entries(id, tenant_id, party_id, kind, amount_paise,
      note, occurred_at, idempotency_key)
      values (p_entry_id, p_tenant_id, p_party_id, p_kind, p_amount_paise, p_note,
        p_occurred_at, p_operation_id)
      on conflict do nothing returning * into entry;
  else
    update public.ledger_entries
      set party_id = p_party_id, kind = p_kind, amount_paise = p_amount_paise,
        note = p_note, occurred_at = p_occurred_at, version = version + 1
      where tenant_id = p_tenant_id and id = p_entry_id and version = p_expected_version
      returning * into entry;
  end if;
  if not found then
    raise exception using errcode = '40001', message = 'Ledger version conflict';
  end if;
  update public.ledger_sync_receipts set result = to_jsonb(entry)
    where tenant_id = p_tenant_id and operation_id = p_operation_id;
  return to_jsonb(entry);
end
$$;
revoke all on function public.apply_ledger_sync_operation(
  uuid, uuid, uuid, bigint, uuid, text, bigint, text, timestamptz) from public, anon, authenticated;
grant execute on function public.apply_ledger_sync_operation(
  uuid, uuid, uuid, bigint, uuid, text, bigint, text, timestamptz) to authenticated;

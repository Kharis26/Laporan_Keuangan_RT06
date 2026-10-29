-- Perbaikan saldo awal.
-- Jalankan setelah schema.sql dan setup_settings.sql.
-- Migration ini aman dijalankan ulang.

alter table public.transaksi_kas
  add column if not exists is_saldo_awal boolean not null default false;

-- Tandai data saldo awal lama yang sebelumnya tersimpan sebagai arah masuk.
update public.transaksi_kas
set is_saldo_awal = true
where lower(trim(kategori)) = 'saldo awal';

create index if not exists transaksi_kas_saldo_awal_idx
  on public.transaksi_kas(is_saldo_awal)
  where is_saldo_awal = true;

create or replace function public.admin_set_saldo_awal(
  p_tanggal date,
  p_nominal bigint,
  p_keterangan text
)
returns public.transaksi_kas
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  result_row public.transaksi_kas;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then
    raise exception 'forbidden: role admin diperlukan';
  end if;
  if p_tanggal is null or p_nominal <= 0 then
    raise exception 'tanggal dan nominal saldo awal wajib valid';
  end if;
  if exists (select 1 from public.transaksi_kas where is_saldo_awal = true and status = 'sah') then
    raise exception 'saldo awal sudah pernah ditetapkan';
  end if;

  insert into public.transaksi_kas(
    tanggal, arah, kategori, nominal, keterangan, is_saldo_awal,
    status, dicatat_oleh, disetujui_oleh
  )
  values (
    p_tanggal, 'masuk', 'Saldo awal', p_nominal,
    nullif(trim(p_keterangan), ''), true,
    'sah', actor, actor
  )
  returning * into result_row;

  insert into public.audit_log(actor_id, action, entity, entity_id, after_data, reason)
  values (
    actor, 'kas.opening_balance', 'transaksi_kas', result_row.id::text,
    to_jsonb(result_row), 'Saldo awal ditetapkan melalui panel Admin'
  );
  return result_row;
end;
$$;

revoke execute on function public.admin_set_saldo_awal(date, bigint, text) from public;
grant execute on function public.admin_set_saldo_awal(date, bigint, text) to authenticated;

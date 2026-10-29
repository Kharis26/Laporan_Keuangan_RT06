-- Migration reset data uji coba.
-- Jalankan setelah setup_settings.sql.
-- Fungsi hanya menghapus data operasional, bukan akun Auth, profiles,
-- pengaturan RT, atau kategori akun bawaan.

create or replace function public.admin_reset_data_uji(p_konfirmasi text)
returns jsonb
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  deleted_count integer := 0;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then
    raise exception 'forbidden: role admin diperlukan';
  end if;
  if p_konfirmasi <> 'RESET RT06' then
    raise exception 'konfirmasi tidak sesuai';
  end if;

  -- Hapus anak/relasi terlebih dahulu agar tidak melanggar foreign key.
  delete from public.transaksi_kas;
  get diagnostics deleted_count = row_count;
  delete from public.alokasi_pembayaran;
  delete from public.pembayaran;
  delete from public.keringanan;
  delete from public.tagihan;
  delete from public.tarif_iuran;
  delete from public.jenis_iuran;
  delete from public.warga;
  delete from public.periode_keuangan;
  delete from public.laporan;
  delete from public.audit_log;

  -- Audit reset tetap ditinggalkan setelah data lama dihapus.
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason)
  values(actor,'data.reset_uji_coba','aplikasi','reset',jsonb_build_object('transaksi_kas_dihapus',deleted_count),'Reset data uji coba melalui panel Admin');

  return jsonb_build_object('ok',true,'transaksi_kas_dihapus',deleted_count);
end;
$$;

revoke execute on function public.admin_reset_data_uji(text) from public;
grant execute on function public.admin_reset_data_uji(text) to authenticated;
comment on function public.admin_reset_data_uji(text) is 'Admin-only destructive reset for test data. Requires exact confirmation RESET RT06.';

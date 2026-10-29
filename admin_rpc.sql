-- Migration RPC admin untuk Keuangan RT Digital.
-- Jalankan setelah supabase/schema.sql pada database Supabase yang sama.
-- Semua fungsi SECURITY DEFINER memvalidasi auth.uid(), role aktif, dan menulis audit log.

create or replace function public.admin_upsert_warga(
  p_id uuid,
  p_nomor_rumah text,
  p_nama_kepala_keluarga text,
  p_alamat text,
  p_kontak text,
  p_mulai_wajib date,
  p_status public.status_warga,
  p_tanggal_efektif_status date,
  p_catatan_admin text
)
returns public.warga
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  old_row public.warga;
  result_row public.warga;
  action_name text;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then
    raise exception 'forbidden: role admin diperlukan';
  end if;
  if nullif(trim(p_nomor_rumah), '') is null or nullif(trim(p_nama_kepala_keluarga), '') is null then
    raise exception 'nomor rumah dan nama kepala keluarga wajib diisi';
  end if;
  if p_status <> 'aktif' and p_tanggal_efektif_status is null then
    raise exception 'tanggal efektif wajib diisi untuk warga nonaktif atau keluar';
  end if;

  if p_id is null then
    insert into public.warga (nomor_rumah,nama_kepala_keluarga,alamat,kontak,mulai_wajib,status,tanggal_efektif_status,catatan_admin,created_by)
    values (trim(p_nomor_rumah),trim(p_nama_kepala_keluarga),nullif(trim(p_alamat),''),nullif(trim(p_kontak),''),p_mulai_wajib,p_status,p_tanggal_efektif_status,p_catatan_admin,actor)
    returning * into result_row;
    action_name := 'warga.create';
  else
    select * into old_row from public.warga where id = p_id for update;
    if not found then raise exception 'warga tidak ditemukan'; end if;
    update public.warga
    set nomor_rumah=trim(p_nomor_rumah), nama_kepala_keluarga=trim(p_nama_kepala_keluarga), alamat=nullif(trim(p_alamat),''), kontak=nullif(trim(p_kontak),''), mulai_wajib=p_mulai_wajib, status=p_status, tanggal_efektif_status=p_tanggal_efektif_status, catatan_admin=p_catatan_admin, updated_at=now()
    where id=p_id
    returning * into result_row;
    action_name := 'warga.update';
  end if;

  insert into public.audit_log(actor_id,action,entity,entity_id,before_data,after_data,reason)
  values (actor,action_name,'warga',result_row.id::text,case when old_row.id is null then null else to_jsonb(old_row) end,to_jsonb(result_row),'Perubahan melalui panel admin');
  return result_row;
end;
$$;

create or replace function public.admin_upsert_jenis_iuran(
  p_id uuid,
  p_nama text,
  p_periode text,
  p_aktif boolean
)
returns public.jenis_iuran
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); old_row public.jenis_iuran; result_row public.jenis_iuran; action_name text;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if nullif(trim(p_nama),'') is null or p_periode not in ('bulanan','tahunan','sekali') then raise exception 'nama dan periode iuran tidak valid'; end if;
  if p_id is null then
    insert into public.jenis_iuran(nama,periode,aktif) values(trim(p_nama),p_periode,p_aktif) returning * into result_row;
    action_name := 'jenis_iuran.create';
  else
    select * into old_row from public.jenis_iuran where id=p_id for update;
    if not found then raise exception 'jenis iuran tidak ditemukan'; end if;
    update public.jenis_iuran set nama=trim(p_nama),periode=p_periode,aktif=p_aktif where id=p_id returning * into result_row;
    action_name := 'jenis_iuran.update';
  end if;
  insert into public.audit_log(actor_id,action,entity,entity_id,before_data,after_data,reason) values(actor,action_name,'jenis_iuran',result_row.id::text,case when old_row.id is null then null else to_jsonb(old_row) end,to_jsonb(result_row),'Perubahan melalui panel admin');
  return result_row;
end;
$$;

create or replace function public.admin_upsert_tarif_iuran(
  p_id uuid,
  p_jenis_iuran_id uuid,
  p_nominal bigint,
  p_berlaku_mulai date,
  p_berlaku_sampai date
)
returns public.tarif_iuran
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); old_row public.tarif_iuran; result_row public.tarif_iuran; action_name text;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if p_jenis_iuran_id is null or p_nominal < 0 or p_berlaku_mulai is null or (p_berlaku_sampai is not null and p_berlaku_sampai < p_berlaku_mulai) then raise exception 'tarif iuran tidak valid'; end if;
  if not exists(select 1 from public.jenis_iuran where id=p_jenis_iuran_id) then raise exception 'jenis iuran tidak ditemukan'; end if;
  if p_id is null then
    insert into public.tarif_iuran(jenis_iuran_id,nominal,berlaku_mulai,berlaku_sampai,created_by) values(p_jenis_iuran_id,p_nominal,p_berlaku_mulai,p_berlaku_sampai,actor) returning * into result_row;
    action_name := 'tarif_iuran.create';
  else
    select * into old_row from public.tarif_iuran where id=p_id for update;
    if not found then raise exception 'tarif iuran tidak ditemukan'; end if;
    update public.tarif_iuran set jenis_iuran_id=p_jenis_iuran_id,nominal=p_nominal,berlaku_mulai=p_berlaku_mulai,berlaku_sampai=p_berlaku_sampai where id=p_id returning * into result_row;
    action_name := 'tarif_iuran.update';
  end if;
  insert into public.audit_log(actor_id,action,entity,entity_id,before_data,after_data,reason) values(actor,action_name,'tarif_iuran',result_row.id::text,case when old_row.id is null then null else to_jsonb(old_row) end,to_jsonb(result_row),'Perubahan melalui panel admin');
  return result_row;
end;
$$;

create or replace function public.generate_tagihan_bulanan(p_periode text)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); inserted_count integer;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if p_periode !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'periode tidak valid'; end if;
  insert into public.tagihan(warga_id,jenis_iuran_id,periode,tarif_iuran_id,nominal_tarif,created_by)
  select w.id,j.id,p_periode,t.id,t.nominal,actor
  from public.warga w
  cross join public.jenis_iuran j
  join lateral (select ti.id,ti.nominal from public.tarif_iuran ti where ti.jenis_iuran_id=j.id and ti.berlaku_mulai <= (p_periode||'-01')::date and (ti.berlaku_sampai is null or ti.berlaku_sampai >= (p_periode||'-01')::date) order by ti.berlaku_mulai desc,ti.created_at desc limit 1) t on true
  where w.status='aktif' and w.mulai_wajib <= (p_periode||'-01')::date and j.aktif and j.periode='bulanan'
  on conflict (warga_id,jenis_iuran_id,periode) do nothing;
  get diagnostics inserted_count = row_count;
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason) values(actor,'tagihan.generate','tagihan',p_periode,jsonb_build_object('periode',p_periode,'inserted',inserted_count),'Generate tagihan melalui panel admin');
  return inserted_count;
end;
$$;

create or replace function public.catat_pembayaran(
  p_idempotency_key text,
  p_tanggal date,
  p_nominal bigint,
  p_tagihan_id uuid,
  p_keterangan text
)
returns public.pembayaran
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); existing public.pembayaran; bill public.tagihan; result_row public.pembayaran; paid bigint;
begin
  if actor is null or not public.has_any_role(array['admin','bendahara','petugas_iuran']::public.peran_pengurus[]) then raise exception 'forbidden: role keuangan diperlukan'; end if;
  if nullif(trim(p_idempotency_key),'') is null or p_nominal <= 0 or p_tagihan_id is null then raise exception 'pembayaran tidak valid'; end if;
  select * into existing from public.pembayaran where idempotency_key=trim(p_idempotency_key);
  if found then
    if existing.nominal <> p_nominal or existing.tanggal <> p_tanggal then raise exception 'idempotency key sudah dipakai dengan isi berbeda'; end if;
    return existing;
  end if;
  select * into bill from public.tagihan where id=p_tagihan_id for update;
  if not found or bill.status_periode <> 'terbuka' then raise exception 'tagihan tidak ditemukan atau periode sudah ditutup'; end if;
  select coalesce(sum(a.nominal) filter(where p.status='sah'),0) into paid from public.alokasi_pembayaran a join public.pembayaran p on p.id=a.pembayaran_id where a.tagihan_id=p_tagihan_id;
  if p_nominal > bill.nominal_akhir - paid then raise exception 'nominal pembayaran melebihi sisa tagihan'; end if;
  insert into public.pembayaran(idempotency_key,tanggal,nominal,status,keterangan,penerima_id) values(trim(p_idempotency_key),p_tanggal,p_nominal,'sah',p_keterangan,actor) returning * into result_row;
  insert into public.alokasi_pembayaran(pembayaran_id,tagihan_id,nominal) values(result_row.id,p_tagihan_id,p_nominal);
  insert into public.transaksi_kas(tanggal,arah,kategori,nominal,pembayaran_id,keterangan,status,dicatat_oleh,disetujui_oleh) values(p_tanggal,'masuk','iuran',p_nominal,result_row.id,p_keterangan,'sah',actor,actor);
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason) values(actor,'pembayaran.create','pembayaran',result_row.id::text,to_jsonb(result_row),'Pembayaran dicatat atomik melalui RPC');
  return result_row;
end;
$$;

create or replace function public.catat_transaksi_kas(
  p_tanggal date,
  p_arah public.arah_kas,
  p_kategori text,
  p_nominal bigint,
  p_keterangan text,
  p_bukti_path text
)
returns public.transaksi_kas
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); result_row public.transaksi_kas;
begin
  if actor is null or not public.has_any_role(array['admin','bendahara']::public.peran_pengurus[]) then raise exception 'forbidden: role admin atau bendahara diperlukan'; end if;
  if p_nominal <= 0 or nullif(trim(p_kategori),'') is null then raise exception 'transaksi kas tidak valid'; end if;
  insert into public.transaksi_kas(tanggal,arah,kategori,nominal,keterangan,bukti_path,status,dicatat_oleh,disetujui_oleh) values(p_tanggal,p_arah,trim(p_kategori),p_nominal,p_keterangan,p_bukti_path,'sah',actor,actor) returning * into result_row;
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason) values(actor,'kas.create','transaksi_kas',result_row.id::text,to_jsonb(result_row),'Transaksi kas dicatat melalui RPC');
  return result_row;
end;
$$;

revoke execute on function public.admin_upsert_warga(uuid,text,text,text,text,date,public.status_warga,date,text) from public;
revoke execute on function public.admin_upsert_jenis_iuran(uuid,text,text,boolean) from public;
revoke execute on function public.admin_upsert_tarif_iuran(uuid,uuid,bigint,date,date) from public;
revoke execute on function public.generate_tagihan_bulanan(text) from public;
revoke execute on function public.catat_pembayaran(text,date,bigint,uuid,text) from public;
revoke execute on function public.catat_transaksi_kas(date,public.arah_kas,text,bigint,text,text) from public;
grant execute on function public.admin_upsert_warga(uuid,text,text,text,text,date,public.status_warga,date,text) to authenticated;
grant execute on function public.admin_upsert_jenis_iuran(uuid,text,text,boolean) to authenticated;
grant execute on function public.admin_upsert_tarif_iuran(uuid,uuid,bigint,date,date) to authenticated;
grant execute on function public.generate_tagihan_bulanan(text) to authenticated;
grant execute on function public.catat_pembayaran(text,date,bigint,uuid,text) to authenticated;
grant execute on function public.catat_transaksi_kas(date,public.arah_kas,text,bigint,text,text) to authenticated;

comment on function public.admin_upsert_warga(uuid,text,text,text,text,date,public.status_warga,date,text) is 'Admin-only audited warga mutation';
comment on function public.catat_pembayaran(text,date,bigint,uuid,text) is 'Atomic idempotent payment allocation and cash receipt';
comment on function public.catat_transaksi_kas(date,public.arah_kas,text,bigint,text,text) is 'Audited admin/bendahara cash mutation';


-- Koreksi transaksi kas manual dengan alasan wajib dan audit trail before/after.
-- Transaksi yang berasal dari pembayaran iuran dan saldo awal tidak boleh diedit melalui RPC ini.
create or replace function public.admin_koreksi_transaksi_kas(
  p_id uuid,
  p_tanggal date,
  p_arah public.arah_kas,
  p_kategori text,
  p_nominal bigint,
  p_keterangan text,
  p_bukti_path text,
  p_alasan_koreksi text
)
returns public.transaksi_kas
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  old_row public.transaksi_kas;
  result_row public.transaksi_kas;
begin
  if actor is null or not public.has_any_role(array['admin','bendahara']::public.peran_pengurus[]) then
    raise exception 'forbidden: role admin atau bendahara diperlukan';
  end if;
  if p_id is null or p_tanggal is null or p_nominal is null or p_nominal <= 0 or nullif(trim(p_kategori),'') is null then
    raise exception 'data transaksi tidak valid';
  end if;
  if length(trim(coalesce(p_alasan_koreksi,''))) < 5 then
    raise exception 'alasan koreksi wajib diisi minimal 5 karakter';
  end if;

  select * into old_row from public.transaksi_kas where id=p_id for update;
  if not found then raise exception 'transaksi tidak ditemukan'; end if;
  if old_row.status <> 'sah' then raise exception 'hanya transaksi sah yang dapat dikoreksi'; end if;
  if old_row.pembayaran_id is not null then raise exception 'transaksi yang terhubung dengan pembayaran iuran tidak boleh diedit melalui menu arus kas'; end if;
  if lower(trim(old_row.kategori))='saldo awal' then raise exception 'saldo awal tidak dapat diedit melalui menu arus kas'; end if;

  update public.transaksi_kas
     set tanggal=p_tanggal, arah=p_arah, kategori=trim(p_kategori), nominal=p_nominal,
         keterangan=p_keterangan, bukti_path=p_bukti_path, alasan_koreksi=trim(p_alasan_koreksi)
   where id=p_id returning * into result_row;

  insert into public.audit_log(actor_id,action,entity,entity_id,before_data,after_data,reason)
  values(actor,'kas.correct','transaksi_kas',result_row.id::text,to_jsonb(old_row),to_jsonb(result_row),trim(p_alasan_koreksi));
  return result_row;
end;
$$;

revoke execute on function public.admin_koreksi_transaksi_kas(uuid,date,public.arah_kas,text,bigint,text,text,text) from public;
grant execute on function public.admin_koreksi_transaksi_kas(uuid,date,public.arah_kas,text,bigint,text,text,text) to authenticated;
comment on function public.admin_koreksi_transaksi_kas(uuid,date,public.arah_kas,text,bigint,text,text,text) is 'Admin/bendahara audited correction of manual cash transactions; linked payments and opening balance are protected';

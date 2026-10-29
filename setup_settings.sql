-- Migration pengaturan awal aplikasi.
-- Jalankan setelah schema.sql, admin_rpc.sql, simple_mode_step1.sql,
-- dan simple_mode.sql.

create table if not exists public.pengaturan_rt (
  id boolean primary key default true check (id = true),
  nama_bendahara text not null default '',
  nama_ketua_rt text not null default '',
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);
insert into public.pengaturan_rt (id) values (true) on conflict (id) do nothing;

create table if not exists public.kategori_kas (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  arah public.arah_kas,
  aktif boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
insert into public.kategori_kas (nama, arah) values
  ('Saldo awal','masuk'),
  ('Iuran kas','masuk'),
  ('Donasi','masuk'),
  ('Operasional','keluar')
on conflict (nama) do nothing;

alter table public.pengaturan_rt enable row level security;
alter table public.kategori_kas enable row level security;

drop policy if exists "pengaturan_read_authenticated" on public.pengaturan_rt;
create policy "pengaturan_read_authenticated" on public.pengaturan_rt for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','sekretaris','pemeriksa','warga']::public.peran_pengurus[]));
drop policy if exists "kategori_read_authenticated" on public.kategori_kas;
create policy "kategori_read_authenticated" on public.kategori_kas for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','sekretaris','pemeriksa','warga']::public.peran_pengurus[]));
revoke insert, update, delete on public.pengaturan_rt, public.kategori_kas from anon, authenticated;
grant select on public.pengaturan_rt, public.kategori_kas to authenticated;

create or replace function public.admin_simpan_pengaturan(
  p_nama_bendahara text,
  p_nama_ketua_rt text
)
returns public.pengaturan_rt
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); result_row public.pengaturan_rt; old_row public.pengaturan_rt;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if nullif(trim(p_nama_bendahara),'') is null or nullif(trim(p_nama_ketua_rt),'') is null then raise exception 'nama Bendahara dan Ketua RT wajib diisi'; end if;
  select * into old_row from public.pengaturan_rt where id=true for update;
  update public.pengaturan_rt set nama_bendahara=trim(p_nama_bendahara), nama_ketua_rt=trim(p_nama_ketua_rt), updated_by=actor, updated_at=now() where id=true returning * into result_row;
  insert into public.audit_log(actor_id,action,entity,entity_id,before_data,after_data,reason) values(actor,'pengaturan.update','pengaturan_rt','true',to_jsonb(old_row),to_jsonb(result_row),'Pengaturan awal aplikasi diubah melalui panel Admin');
  return result_row;
end;
$$;

create or replace function public.admin_tambah_kategori(
  p_nama text,
  p_arah public.arah_kas
)
returns public.kategori_kas
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); result_row public.kategori_kas;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if nullif(trim(p_nama),'') is null then raise exception 'nama kategori wajib diisi'; end if;
  insert into public.kategori_kas(nama,arah,created_by) values(trim(p_nama),p_arah,actor) returning * into result_row;
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason) values(actor,'kategori_kas.create','kategori_kas',result_row.id::text,to_jsonb(result_row),'Kategori akun kas ditambahkan melalui panel Admin');
  return result_row;
exception when unique_violation then raise exception 'kategori tersebut sudah ada';
end;
$$;

create or replace function public.admin_set_saldo_awal(
  p_tanggal date,
  p_nominal bigint,
  p_keterangan text
)
returns public.transaksi_kas
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare actor uuid := auth.uid(); result_row public.transaksi_kas;
begin
  if actor is null or not public.has_any_role(array['admin']::public.peran_pengurus[]) then raise exception 'forbidden: role admin diperlukan'; end if;
  if p_tanggal is null or p_nominal <= 0 then raise exception 'tanggal dan nominal saldo awal wajib valid'; end if;
  if exists(select 1 from public.transaksi_kas where kategori='Saldo awal' and status='sah') then raise exception 'saldo awal sudah pernah ditetapkan'; end if;
  insert into public.transaksi_kas(tanggal,arah,kategori,nominal,keterangan,status,dicatat_oleh,disetujui_oleh)
  values(p_tanggal,'masuk','Saldo awal',p_nominal,nullif(trim(p_keterangan),''),'sah',actor,actor) returning * into result_row;
  insert into public.audit_log(actor_id,action,entity,entity_id,after_data,reason) values(actor,'kas.opening_balance','transaksi_kas',result_row.id::text,to_jsonb(result_row),'Saldo awal ditetapkan melalui panel Admin');
  return result_row;
end;
$$;

revoke execute on function public.admin_simpan_pengaturan(text,text) from public;
revoke execute on function public.admin_tambah_kategori(text,public.arah_kas) from public;
revoke execute on function public.admin_set_saldo_awal(date,bigint,text) from public;
grant execute on function public.admin_simpan_pengaturan(text,text) to authenticated;
grant execute on function public.admin_tambah_kategori(text,public.arah_kas) to authenticated;
grant execute on function public.admin_set_saldo_awal(date,bigint,text) to authenticated;

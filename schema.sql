-- Keuangan RT Digital — schema awal Supabase/PostgreSQL
-- Terapkan di proyek BARU/lingkungan uji terlebih dahulu. Jangan jalankan tanpa review di database berisi data.
create extension if not exists pgcrypto;

create type public.peran_pengurus as enum ('admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa');
create type public.status_warga as enum ('aktif','nonaktif','keluar');
create type public.status_transaksi as enum ('sah','menunggu','dibatalkan');
create type public.arah_kas as enum ('masuk','keluar','transfer_masuk','transfer_keluar');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  nama text not null,
  roles public.peran_pengurus[] not null default '{}',
  aktif boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.warga (
  id uuid primary key default gen_random_uuid(),
  nomor_rumah text not null,
  nama_kepala_keluarga text not null,
  alamat text,
  kontak text,
  mulai_wajib date not null,
  status public.status_warga not null default 'aktif',
  tanggal_efektif_status date,
  catatan_admin text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(nomor_rumah)) between 1 and 40),
  check (length(trim(nama_kepala_keluarga)) between 1 and 150)
);
create index warga_status_start_idx on public.warga(status,mulai_wajib);
create index warga_house_idx on public.warga(nomor_rumah);

create table public.jenis_iuran (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  periode text not null default 'bulanan' check (periode in ('bulanan','tahunan','sekali')),
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.tarif_iuran (
  id uuid primary key default gen_random_uuid(),
  jenis_iuran_id uuid not null references public.jenis_iuran(id) on delete restrict,
  nominal bigint not null check(nominal >= 0),
  berlaku_mulai date not null,
  berlaku_sampai date,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  check (berlaku_sampai is null or berlaku_sampai >= berlaku_mulai)
);
create index tarif_iuran_lookup_idx on public.tarif_iuran(jenis_iuran_id,berlaku_mulai);

create table public.periode_keuangan (
  id uuid primary key default gen_random_uuid(),
  kode text not null unique,
  mulai date not null,
  akhir date not null,
  status text not null default 'terbuka' check(status in ('terbuka','ditutup','sementara')),
  ditutup_oleh uuid references public.profiles(id),
  ditutup_pada timestamptz,
  check(akhir >= mulai)
);

create table public.tagihan (
  id uuid primary key default gen_random_uuid(),
  warga_id uuid not null references public.warga(id) on delete restrict,
  jenis_iuran_id uuid not null references public.jenis_iuran(id) on delete restrict,
  periode text not null check(periode ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  tarif_iuran_id uuid references public.tarif_iuran(id) on delete restrict,
  nominal_tarif bigint not null check(nominal_tarif >= 0),
  nominal_keringanan bigint not null default 0 check(nominal_keringanan >= 0),
  nominal_akhir bigint generated always as (greatest(0,nominal_tarif-nominal_keringanan)) stored,
  status_periode text not null default 'terbuka' check(status_periode in ('terbuka','ditutup')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(warga_id,jenis_iuran_id,periode),
  check(nominal_keringanan <= nominal_tarif)
);
create index tagihan_periode_idx on public.tagihan(periode,jenis_iuran_id);

create table public.pembayaran (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  tanggal date not null,
  nominal bigint not null check(nominal > 0),
  status public.status_transaksi not null default 'sah',
  keterangan text,
  penerima_id uuid not null references public.profiles(id),
  dibuat_pada timestamptz not null default now(),
  dibatalkan_oleh uuid references public.profiles(id),
  alasan_koreksi text
);
create table public.alokasi_pembayaran (
  id uuid primary key default gen_random_uuid(),
  pembayaran_id uuid not null references public.pembayaran(id) on delete restrict,
  tagihan_id uuid not null references public.tagihan(id) on delete restrict,
  nominal bigint not null check(nominal > 0),
  created_at timestamptz not null default now()
);
create index alokasi_tagihan_idx on public.alokasi_pembayaran(tagihan_id);

create table public.transaksi_kas (
  id uuid primary key default gen_random_uuid(),
  tanggal date not null,
  arah public.arah_kas not null,
  kategori text not null,
  nominal bigint not null check(nominal > 0),
  pembayaran_id uuid references public.pembayaran(id) on delete restrict,
  keterangan text,
  bukti_path text,
  status public.status_transaksi not null default 'sah',
  dicatat_oleh uuid not null references public.profiles(id),
  disetujui_oleh uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  alasan_koreksi text
);
create unique index kas_satu_penerimaan_per_pembayaran
  on public.transaksi_kas(pembayaran_id) where pembayaran_id is not null and arah='masuk';

create table public.keringanan (
  id uuid primary key default gen_random_uuid(),
  warga_id uuid not null references public.warga(id) on delete restrict,
  jenis_iuran_id uuid not null references public.jenis_iuran(id) on delete restrict,
  periode_mulai text not null,
  periode_sampai text not null,
  jenis text not null check(jenis in ('pembebasan_penuh','pengurangan','penundaan')),
  nominal_pengurangan bigint not null default 0 check(nominal_pengurangan >= 0),
  alasan_rahasia text not null,
  status text not null default 'diajukan' check(status in ('diajukan','disetujui','ditolak','ditinjau','berakhir')),
  diajukan_oleh uuid not null references public.profiles(id),
  disetujui_oleh uuid references public.profiles(id),
  dicatat_oleh uuid references public.profiles(id),
  mulai_berlaku date not null,
  berakhir_pada date,
  created_at timestamptz not null default now(),
  check(periode_mulai ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  check(periode_sampai ~ '^[0-9]{4}-(0[1-9]|1[0-2])$')
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity text not null,
  entity_id text,
  before_data jsonb,
  after_data jsonb,
  reason text,
  created_at timestamptz not null default now()
);
create index audit_created_idx on public.audit_log(created_at desc);

create table public.laporan (
  id uuid primary key default gen_random_uuid(),
  jenis text not null check(jenis in ('bulanan','tahunan','serah_terima')),
  periode_mulai date not null,
  periode_akhir date not null,
  status text not null default 'draf' check(status in ('draf','sementara','final','dikoreksi')),
  snapshot jsonb not null,
  dibuat_oleh uuid references public.profiles(id),
  disetujui_oleh uuid references public.profiles(id),
  versi integer not null default 1,
  laporan_asal_id uuid references public.laporan(id),
  created_at timestamptz not null default now(),
  check(periode_akhir >= periode_mulai)
);

create or replace function public.current_roles()
returns public.peran_pengurus[] language sql stable security definer
set search_path = public, pg_temp as $$
  select roles from public.profiles where id=auth.uid() and aktif=true
$$;
create or replace function public.has_any_role(required public.peran_pengurus[])
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select coalesce(public.current_roles() && required,false)
$$;
create or replace function public.profil_saya()
returns jsonb language sql stable security definer
set search_path = public, pg_temp as $$
  select jsonb_build_object('roles',roles,'aktif',aktif,'nama',nama)
  from public.profiles where id=auth.uid()
$$;

-- RLS: client can read only approved operational data; all writes are via audited RPCs.
alter table public.profiles enable row level security;
alter table public.warga enable row level security;
alter table public.jenis_iuran enable row level security;
alter table public.tarif_iuran enable row level security;
alter table public.periode_keuangan enable row level security;
alter table public.tagihan enable row level security;
alter table public.pembayaran enable row level security;
alter table public.alokasi_pembayaran enable row level security;
alter table public.transaksi_kas enable row level security;
alter table public.keringanan enable row level security;
alter table public.audit_log enable row level security;
alter table public.laporan enable row level security;

create policy "profiles_read_self_or_admin" on public.profiles for select to authenticated
using (id=auth.uid() or public.has_any_role(array['admin']::public.peran_pengurus[]));
create policy "warga_read_staff" on public.warga for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));
create policy "fees_read_staff" on public.jenis_iuran for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));
create policy "tarif_read_staff" on public.tarif_iuran for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));
create policy "periode_read_staff" on public.periode_keuangan for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));
create policy "tagihan_read_staff" on public.tagihan for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));
create policy "pembayaran_read_staff" on public.pembayaran for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','pemeriksa']::public.peran_pengurus[]));
create policy "alokasi_read_staff" on public.alokasi_pembayaran for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','pemeriksa']::public.peran_pengurus[]));
create policy "kas_read_staff" on public.transaksi_kas for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','pemeriksa']::public.peran_pengurus[]));
create policy "keringanan_read_privileged" on public.keringanan for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','pemeriksa']::public.peran_pengurus[]));
create policy "audit_read_staff" on public.audit_log for select to authenticated
using (public.has_any_role(array['admin','bendahara','petugas_iuran','ketua_rt','pemeriksa']::public.peran_pengurus[]));
create policy "laporan_read_staff" on public.laporan for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','sekretaris','pemeriksa']::public.peran_pengurus[]));

-- No direct writes from browser: create audited, narrowly-scoped RPCs after reviewing policies.
revoke insert, update, delete on all tables in schema public from anon, authenticated;
grant select on public.profiles,public.warga,public.jenis_iuran,public.tarif_iuran,public.periode_keuangan,public.tagihan,public.pembayaran,public.alokasi_pembayaran,public.transaksi_kas,public.keringanan,public.audit_log,public.laporan to authenticated;
grant execute on function public.current_roles() to authenticated;
grant execute on function public.has_any_role(public.peran_pengurus[]) to authenticated;
grant execute on function public.profil_saya() to authenticated;

-- Views used by the starter UI. Views must obey invoker permissions/RLS.
create or replace view public.tagihan_ringkas with (security_invoker=true) as
select t.id,t.warga_id,t.jenis_iuran_id,t.periode,t.nominal_akhir,
       coalesce(sum(a.nominal) filter(where p.status='sah'),0)::bigint as dibayar,
       w.nomor_rumah,w.nama_kepala_keluarga,j.nama as nama_iuran
from public.tagihan t
join public.warga w on w.id=t.warga_id
join public.jenis_iuran j on j.id=t.jenis_iuran_id
left join public.alokasi_pembayaran a on a.tagihan_id=t.id
left join public.pembayaran p on p.id=a.pembayaran_id
group by t.id,w.nomor_rumah,w.nama_kepala_keluarga,j.nama;
create or replace view public.saldo_kas_ringkas with (security_invoker=true) as
select coalesce(sum(case when arah in ('masuk','transfer_masuk') then nominal
                         when arah in ('keluar','transfer_keluar') then -nominal else 0 end),0)::bigint as saldo
from public.transaksi_kas where status='sah';
grant select on public.tagihan_ringkas,public.saldo_kas_ringkas to authenticated;

-- IMPORTANT: all mutations intentionally remain unavailable until audited RPCs are added.

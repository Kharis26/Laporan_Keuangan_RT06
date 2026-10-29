-- Isi kategori akun kas default.
-- Jalankan di Supabase SQL Editor pada project yang sama dengan aplikasi.
-- Aman dijalankan ulang karena memakai ON CONFLICT.

insert into public.kategori_kas (nama, arah, aktif)
values
  ('Saldo awal', 'masuk', true),
  ('Iuran kas', 'masuk', true),
  ('Donasi', 'masuk', true),
  ('Operasional', 'keluar', true)
on conflict (nama) do update
set
  arah = excluded.arah,
  aktif = true;

grant select on public.kategori_kas to authenticated;

-- Verifikasi hasil:
select id, nama, arah, aktif
from public.kategori_kas
where aktif = true
order by nama;

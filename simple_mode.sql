-- LANGKAH 2 — jalankan file ini setelah simple_mode_step1.sql berhasil.
-- PostgreSQL harus sudah melakukan commit enum `warga` sebelum policy memakai nilai tersebut.
-- Jalankan seluruh isi file ini sebagai query terpisah.

-- Warga hanya membaca transaksi kas yang sudah sah dan laporan.
drop policy if exists "kas_read_staff" on public.transaksi_kas;
create policy "kas_read_admin_or_warga" on public.transaksi_kas for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','sekretaris','pemeriksa','warga']::public.peran_pengurus[]));

drop policy if exists "laporan_read_staff" on public.laporan;
create policy "laporan_read_admin_or_warga" on public.laporan for select to authenticated
using (public.has_any_role(array['admin','bendahara','ketua_rt','sekretaris','pemeriksa','warga']::public.peran_pengurus[]));

-- Admin-only mutation tetap melalui RPC. Tidak ada INSERT/UPDATE/DELETE langsung.
revoke insert, update, delete on public.transaksi_kas, public.laporan from anon, authenticated;

comment on table public.transaksi_kas is 'Arus kas utama. Iuran bulanan dicatat manual di luar aplikasi dan hanya transaksi keuangan yang dimasukkan di sini.';
comment on table public.laporan is 'Snapshot LPJ jika nanti diperlukan; versi sederhana menghitung LPJ dari arus kas sah.';

# Supabase setup
1. Buat proyek Supabase baru atau gunakan proyek kosong untuk uji.
2. Buka SQL Editor, jalankan `schema.sql`.
3. Periksa hasilnya dan jalankan uji RLS sebelum mengisi data.
4. Authentication > Providers: aktifkan Email.
5. Buat pengguna pengurus melalui Supabase Auth.
6. Profil `public.profiles` harus dibuat oleh Admin tepercaya (Dashboard/SQL Editor) dengan `id` sama persis dengan `auth.users.id`; jangan memberi izin pengguna membuat perannya sendiri.
7. Isi `config.js` dengan Project URL dan anon/publishable key.
8. Jalankan secara lokal lewat server static atau deploy Vercel.
9. Jangan memasukkan service_role key ke browser atau GitHub.

## Migration input admin

Setelah schema utama berhasil dijalankan pada proyek Supabase, jalankan `supabase/admin_rpc.sql`. Migration ini menambahkan fungsi RPC `SECURITY DEFINER` untuk menyimpan warga, jenis iuran, tarif, generate tagihan bulanan, pembayaran atomik/idempotent, dan kas masuk/keluar. Browser tetap tidak mendapat hak tulis langsung. Uji role dan audit trail pada data uji sebelum data warga asli.

## Mode sederhana Arus Kas + LPJ

Jalankan `supabase/simple_mode_step1.sql` sendiri dan tunggu commit, lalu jalankan `supabase/simple_mode.sql` sebagai query terpisah setelah `admin_rpc.sql`. Migration ini menambahkan role `warga`, membuka baca transaksi kas dan laporan untuk warga, serta tetap menutup seluruh penulisan langsung dari browser. Iuran bulanan tidak dibuat di aplikasi.


## Pengaturan awal Admin

Jalankan `setup_settings.sql` setelah migration mode sederhana. Migration ini membuat tabel pengaturan RT, kategori akun kas, dan tiga RPC Admin untuk menyimpan identitas LPJ, saldo awal satu kali, serta kategori baru.


## Reset data uji coba

Jalankan `reset_data.sql` setelah `setup_settings.sql` bila tombol reset diperlukan. Hanya Admin yang dapat menjalankan RPC ini, dengan konfirmasi teks `RESET RT06` dan konfirmasi browser kedua.


## Perbaikan saldo awal

Jalankan `fix_saldo_awal.sql` setelah `setup_settings.sql`. Saldo awal tetap menambah saldo kas, tetapi tidak masuk total pemasukan.

# Keuangan RT Digital — versi sederhana

Aplikasi ini sengaja dipersempit menjadi tiga fungsi: **Arus Kas**, **LPJ Bulanan**, dan **LPJ Tahunan**. Iuran bulanan dibuat dan direkap manual di luar aplikasi. Yang dimasukkan ke aplikasi hanya transaksi uang yang benar-benar diterima atau dikeluarkan.

## Mode pengguna

- **Admin**: dapat mencatat pemasukan dan pengeluaran melalui RPC Supabase. Transaksi sah tidak dihapus.
- **Warga**: login dengan akun yang dibuat Admin, lalu hanya dapat membaca arus kas dan LPJ.
- Tidak ada pendaftaran publik dan tidak ada service_role key di browser.

## Setup Supabase

1. Jalankan `supabase/schema.sql` pada database kosong atau proyek uji.
2. Jalankan `supabase/admin_rpc.sql`.
3. Jalankan `supabase/simple_mode_step1.sql` sendiri terlebih dahulu, klik Run dan tunggu selesai. Setelah itu jalankan `supabase/simple_mode.sql` sebagai query terpisah untuk menambahkan akses baca warga.
4. Buat akun di Supabase Authentication.
5. Buat profil dengan UUID yang sama:
   - Admin: `roles = ARRAY['admin']`
   - Warga: `roles = ARRAY['warga']`
   - Set `aktif = true`.
6. `config.js` sudah disesuaikan dengan Project URL dan publishable key Supabase yang diberikan pengguna. Ini hanya mengatur koneksi frontend; agar aplikasi benar-benar berfungsi, skema tabel, RPC, profil pengguna, dan kebijakan RLS yang cocok harus tersedia di proyek tersebut. Key browser ini boleh tampil di frontend hanya jika RLS dan grant sudah benar; jangan pernah gunakan `service_role` atau secret key.
7. Jalankan `supabase/setup_settings.sql` untuk membuat menu Pengaturan Admin: identitas Bendahara/Ketua RT, saldo awal, dan kategori akun.
8. Jalankan `supabase/reset_data.sql` jika ingin mengaktifkan tombol reset data uji coba.
9. Logo RT tersimpan di `assets/logo-rt06-rw08.jpg` dan tampil di halaman login.

## Pemakaian

1. Admin login.
2. Buka **Arus Kas**.
3. Catat pemasukan atau pengeluaran, konfirmasi nominal, lalu simpan.
4. Buka **LPJ Bulanan** atau **LPJ Tahunan**.
5. Pilih periode dan gunakan tombol **Cetak LPJ** untuk menyimpan sebagai PDF melalui dialog cetak browser.
6. Admin buka menu **Pengaturan** untuk mengisi nama Bendahara/Ketua RT, menetapkan saldo awal satu kali, dan menambah kategori akun kas.
7. Admin dapat memakai tombol **Reset data uji coba** di Pengaturan dengan mengetik `RESET RT06`; aksi ini menghapus data operasional secara permanen tetapi mempertahankan akun, pengaturan RT, dan kategori akun.
8. Pada menu **Arus Kas**, pilih tanggal **Mulai** dan **Sampai**, lalu klik **Cetak Arus Kas** untuk mencetak transaksi pada periode tersebut.
8. Warga login dengan akun role `warga` untuk melihat data tanpa tombol input.

## Catatan perhitungan

Saldo dihitung dari transaksi kas sah: pemasukan dikurangi pengeluaran. LPJ tidak menganggap tunggakan iuran sebagai uang masuk. Saldo awal belum dibuat sebagai input khusus; jika diperlukan, catat sebagai transaksi pembukaan dengan kategori yang jelas. Koreksi transaksi dilakukan dengan transaksi pembalik/koreksi yang memiliki alasan, bukan menghapus data lama.

## Validasi

Perintah yang sudah dijalankan pada versi ini:

```sh
node --check app.js
node --check config.js
node --test tests/business-rules.test.js
```

Lihat `supabase/simple_mode.sql`, `TODO.md`, dan `AUDIT.md` untuk batasan serta migration database.


### Perbaikan saldo awal

Jalankan `supabase/fix_saldo_awal.sql` setelah `setup_settings.sql`. Migration ini menandai saldo awal sebagai saldo pembukaan, bukan pemasukan, dan memperbaiki RPC pengaturannya. Migration ini wajib sebelum memakai fitur saldo awal pada database produksi.

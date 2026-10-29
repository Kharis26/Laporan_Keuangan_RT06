# TODO — Keuangan RT Digital versi sederhana

## Selesai

### 1. Arus Kas sebagai pusat aplikasi
- Iuran bulanan tidak dikelola di aplikasi dan dibuat manual terpisah.
- Admin dapat mencatat pemasukan dan pengeluaran kas melalui RPC.
- Saldo, total pemasukan, total pengeluaran, dan jumlah transaksi dihitung otomatis.
- Tabel dapat dicari dan difilter berdasarkan bulan serta jenis transaksi.

### 2. LPJ Bulanan dan Tahunan
- LPJ bulanan menghitung ringkasan saldo, pemasukan, pengeluaran, kategori, dan daftar transaksi dari periode yang dipilih.
- LPJ tahunan menampilkan rekap 12 bulan serta total kategori.
- Laporan dapat dicetak melalui browser dan disimpan sebagai PDF.

### 3. Pengaturan awal Admin
- Admin dapat mengisi nama Bendahara dan Ketua RT yang otomatis muncul pada LPJ bulanan dan tahunan.
- Admin dapat menetapkan saldo awal satu kali melalui RPC yang diaudit.
- Admin dapat menambah kategori akun kas dan memilihnya saat mencatat transaksi.

### 4. Mode Admin dan Warga
- Admin melihat form pencatatan Arus Kas.
- Warga tidak melihat form edit dan hanya dapat membaca Arus Kas serta LPJ.
- Role `warga` ditambahkan melalui `supabase/simple_mode.sql`.
- Browser tidak mendapat hak tulis langsung; mutasi tetap melalui RPC.

## Terbuka sebelum produksi

### 5. Setup database mode sederhana
- Jalankan `schema.sql`, `admin_rpc.sql`, kemudian `simple_mode_step1.sql` dan `simple_mode.sql` sebagai dua query terpisah, lalu `setup_settings.sql`.
- Buat profil role `admin` dan `warga` dengan UUID yang sama dengan akun Auth.

### 6. Saldo awal dan koreksi
- Tetapkan kategori khusus `Saldo pembukaan` bila saldo awal diperlukan.
- Tambahkan RPC koreksi/pembalik dengan alasan jika Admin membutuhkan workflow koreksi formal.
- Uji periode buku ditutup jika fitur penutupan buku mulai digunakan.

### 7. Pengujian live
- Uji Admin dapat mencatat kas.
- Uji Warga dapat membaca tetapi RPC kas menolak role warga.
- Uji klik berulang, kegagalan jaringan, dan hasil cetak LPJ dengan data uji.


### Perbaikan saldo awal
- Saldo awal tidak masuk total pemasukan; saldo awal hanya menjadi dasar saldo kas.
- Migration `supabase/fix_saldo_awal.sql` menandai data lama dan memperbaiki RPC saldo awal.

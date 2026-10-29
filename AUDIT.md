# Audit statis — Keuangan RT Digital

Tanggal audit: 2026-10-28

## Status

Fondasi static site dapat dideploy ke Vercel, tetapi ZIP ini belum dinyatakan siap untuk pencatatan uang produksi. Pemeriksaan statis dan perbaikan laporan sudah dilakukan; validasi database Supabase live, role/RLS, RPC, rekonsiliasi, serta backup/restore masih wajib dilakukan sebelum penggunaan produksi.

## Temuan yang sudah diperbaiki

- Struktur HTML/CSS/JavaScript tetap dipertahankan dan dipindahkan ke proyek WebDev terkelola.
- Login Supabase sekarang memulihkan sesi, menyinkronkan perubahan auth, mengunci tampilan tanpa sesi, dan menyediakan logout.
- Query warga, tagihan, kas, dan audit dipisah sehingga error atau penolakan RLS dapat ditampilkan per bagian tanpa membocorkan data.
- Nilai database di-escape sebelum masuk ke HTML; filter warga dan pembayaran berjalan di sisi klien atas data yang sudah diizinkan RLS.
- UI memiliki loading, empty, error, status sesi, dan pesan konfigurasi yang jujur.
- Follow-up audit memperbaiki risiko stale data lintas sesi: state dibersihkan setiap perubahan auth, panel utama baru tampil setelah profil aktif tervalidasi, dan request lama dibatalkan secara logis dengan session version guard.
- Filter select memakai event `change`, logout memeriksa error, dan anon JWT yang sah tetap diterima sementara JWT `service_role` ditolak.
- Mutasi finansial tidak disediakan karena schema belum memiliki RPC server-side yang diaudit. Pembayaran, kas, koreksi, keringanan, dan LPJ ditandai baca saja.
- Header `X-Frame-Options: DENY` dihapus dari konfigurasi Vercel agar tidak memblokir embedded Preview WebDev. Header keamanan non-blocking tetap dipertahankan.
- `manus-routes.json`, `app.config.ts`, TODO implementasi, dan static build output ditambahkan untuk kesiapan checkpoint/publikasi.

## Temuan arus kas, laporan, dan saldo

1. Ditemukan bug perhitungan LPJ: saldo awal periode sebelumnya tidak dibawa ke saldo awal/akhir bulan dan saldo akhir bulanan pada LPJ tahunan hanya memakai pergerakan bulan itu. Logika diperbaiki agar saldo awal periode dihitung dari transaksi sah sebelum periode, saldo akhir bulan bersifat kumulatif, dan saldo pembukaan berlaku pada tanggal efektifnya.
2. Pengambilan transaksi sebelumnya dibatasi 2.000 baris, berisiko membuat saldo dan LPJ historis tidak lengkap. Diubah menjadi paginasi 1.000 baris sampai semua transaksi terbaca.
3. Daftar transaksi pada LPJ bulanan/tahunan sekarang hanya menampilkan transaksi berstatus `sah`, selaras dengan nilai yang masuk ke perhitungan.
4. Konfigurasi `config.js` berisi URL proyek Supabase dan publishable key. Pastikan proyek itu benar sebelum deploy; jangan pernah memasukkan `service_role` atau secret key.
5. `fix_saldo_awal.sql` wajib dijalankan setelah `setup_settings.sql`, sebab migration tersebut menambahkan penanda saldo pembukaan dan mengganti RPC saldo awal. Jika kolom belum ada, query aplikasi yang membaca transaksi dapat gagal.

## Risiko yang masih terbuka

1. Login, role Admin/Warga, RLS, grant, RPC, serta akses baca lintas akun belum diuji terhadap Supabase live.
2. RPC koreksi/pembalik transaksi dengan alasan, rekonsiliasi formal, dan tutup buku belum tersedia sebagai workflow produksi.
3. Backup harian, retensi 30 hari, alarm kegagalan, dan uji restore belum dikonfigurasi.
4. CDN Supabase belum dipin ke patch version/SRI; ini hardening lanjutan.
5. Belum dilakukan uji cetak PDF dan pengujian transaksi riil melalui browser setelah seluruh migration diterapkan.
6. Static deployment tidak membuktikan bahwa skema database dan RPC sudah benar atau bahwa pengguna memiliki role yang tepat.

## Bukti pemeriksaan

- `node --test tests/business-rules.test.js`: 3/3 lulus.
- `node --check app.js` dan `node --check config.js`: lulus setelah revisi.
- `manus-routes.json` dan `vercel.json`: JSON valid.
- LPJ memakai transaksi sah saja; saldo akhir per bulan dihitung kumulatif.
- Pemuatan arus kas memakai paginasi agar tidak berhenti pada 2.000 transaksi.
- HTTP Preview: `/` dan `/manus-routes.json` mengembalikan 200.
- Screenshot desktop dan mobile: layout login, notifikasi konfigurasi, dan form responsif terbaca.

# Halaman Login Admin

## File
- `web/admin-login.html`: halaman login staf.
- `web/config.example.js`: contoh konfigurasi Supabase. Salin menjadi `web/config.js` di komputer lokal.

## Konfigurasi lokal
1. Unduh folder `web` dari repository.
2. Duplikat `config.example.js`, lalu ubah nama salinannya menjadi `config.js`.
3. Isi `SUPABASE_PUBLISHABLE_KEY` dengan Publishable Key project Supabase.
4. Jangan gunakan `sb_secret_` atau `service_role` key.
5. Buka halaman melalui local web server (bukan file://), misalnya VS Code Live Server.

Project URL sudah diisi untuk project Donation Automation System.

## Fitur yang tersedia
- Login email dan password melalui Supabase Auth.
- Memverifikasi JWT menggunakan `supabase.auth.getClaims()`.
- Hanya menerima role `super_admin`, `fundraising_admin`, `fundraising_staff`, dan `viewer` dengan `staff_active === true`.
- Menolak sesi tanpa role staf aktif dan melakukan sign out.
- Mempertahankan sesi browser melalui Supabase Auth.
- Logout.

## Catatan keamanan dan batas tahap
- Publishable Key memang untuk browser; secret/service_role key tidak boleh dimasukkan ke frontend.
- Pemeriksaan role di halaman hanya untuk alur UI. RLS dan database grants tetap menjadi lapisan otorisasi utama.
- Halaman ini belum mengarah ke dashboard karena halaman dashboard belum dibuat.
- Halaman ini merupakan starter statis untuk tahap awal. Untuk deployment production berbasis SSR, gunakan framework dan `@supabase/ssr` dengan cookie-based sessions dan validasi server-side.

## Menjalankan
Jalankan local web server dari root repository, lalu buka `/web/admin-login.html`. Contoh: VS Code extension Live Server atau `python -m http.server 8000` lalu buka `http://localhost:8000/web/admin-login.html`.

# Halaman Login Admin

## File
- `admin-login.html`: halaman login staf.
- `config.example.js`: contoh konfigurasi Supabase tanpa secret.
- `config.js`: file lokal yang dibuat sendiri dan tidak boleh di-commit.

## Persiapan
1. Salin `config.example.js` menjadi `config.js` di folder `web/`.
2. Buka `config.js` dan pastikan:
   - `SUPABASE_URL` berisi Project URL.
   - `SUPABASE_PUBLISHABLE_KEY` berisi key yang diawali `sb_publishable_` (atau anon key lama).
3. Jangan gunakan `sb_secret_` atau `service_role` key. Jangan kirim key atau password ke chat.
4. Jalankan dari local web server, bukan membuka file HTML dengan skema `file://`. Contoh dengan VS Code Live Server, atau dari folder project:
   ```bash
   python -m http.server 8000
   ```
   Kemudian buka `http://localhost:8000/web/admin-login.html`.

## Cara kerja
- Login menggunakan Supabase Auth email/password.
- Setelah login, halaman memanggil `supabase.auth.getClaims()` untuk memverifikasi access token.
- Hanya akun dengan `staff_active === true` dan salah satu role yang diizinkan yang dapat masuk ke tampilan sesi.
- Role yang dikenali: `super_admin`, `fundraising_admin`, `fundraising_staff`, dan `viewer`.
- Logout memanggil `supabase.auth.signOut()`.
- Halaman ini belum merupakan dashboard dan belum melakukan redirect ke halaman dashboard. Itu tahap berikutnya.

## Catatan keamanan
- Publishable key memang boleh ada di browser; keamanan data tetap bergantung pada RLS dan grants di database.
- Jangan pernah menaruh secret/service_role key di file frontend.
- Jangan deploy halaman ini sebelum konfigurasi Auth redirect/origin, HTTPS, dan kebijakan deployment ditinjau.
- Setelah perubahan role/status staf, terbitkan token baru dengan login ulang/refresh session. JWT yang sudah diterbitkan tidak otomatis berubah.

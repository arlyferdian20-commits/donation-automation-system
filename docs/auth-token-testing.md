# Pengujian JWT dan Custom Access Token Hook

## Tujuan
Memastikan token akses yang diterbitkan Supabase Auth memuat:
- `app_role: "super_admin"`
- `staff_active: true`

## File pengujian
Buka `tests/auth-token-test.html` di browser lokal. Unduh file dari GitHub lalu buka di komputer sendiri.

## Data yang dibutuhkan
1. Project URL: Supabase Dashboard → Project Settings → API → Project URL.
2. Publishable key (atau anon key lama): Supabase Dashboard → Project Settings → API Keys.
3. Email dan password akun staf yang sudah dibuat di Supabase Auth.

**Penting:** Gunakan hanya Publishable Key/anon key. Jangan pernah memasukkan `service_role` atau secret key. Jangan mengirim password atau access token ke chat. File uji ini hanya untuk lokal dan jangan dipublikasikan.

## Langkah
1. Buka file HTML secara lokal di browser.
2. Masukkan Project URL, Publishable Key/anon key, email dan password staf.
3. Klik **Login & Periksa JWT**.
4. Halaman melakukan sign-in dengan Supabase Auth, memverifikasi access token melalui `supabase.auth.getClaims()`, lalu menampilkan klaim yang diperlukan saja.
5. Halaman akan sign out dan mengosongkan kolom password setelah pengujian.

## Hasil yang diharapkan untuk Super Admin
```json
{
  "app_role": "super_admin",
  "staff_active": true,
  "checks": {
    "app_role_is_super_admin": true,
    "staff_active_is_true": true
  },
  "token_verified_by_supabase_getClaims": true
}
```

## Jika gagal
- `Invalid login credentials`: periksa email/password dan pastikan akun Auth ada.
- Klaim role null atau `staff_active: false`: pastikan profil aktif ada di `public.staff_profiles`, lalu login ulang agar token baru diterbitkan.
- Error saat sign-in: periksa Auth logs dan konfigurasi Custom Access Token Hook.
- Jangan menempelkan password, access token, refresh token, atau secret key ke issue, chat, atau repository.

Catatan: Pengujian ini memverifikasi JWT yang baru diterbitkan. Perubahan role tidak otomatis mengubah JWT yang sudah diterbitkan sebelumnya.

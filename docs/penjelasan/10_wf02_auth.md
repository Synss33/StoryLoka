# WF-02 — Autentikasi, Sesi, Biometrik & Logout

> **Fitur:** F-01 (login terenkripsi), F-02 (session), F-03 (biometrik), F-09 (logout) · **Layar:** SCR-01, SCR-09 (bagian keamanan) · **Alur:** workflow §3.1–3.2 · **Test:** TC-01…TC-08 (`auth_flow_test`, `session_test`, `password_hasher_test`)

## 1. Alur fitur (workflow §3.1–3.2 → kode)

**Start & sesi** — `features/auth/splash_screen.dart:17`:
```
Splash 1,5 dtk (logo + tagline) sambil periksa sesi →
  tidak ada sesi         → /auth (form login/register)
  sesi kedaluwarsa       → /auth + dialog "Sesi berakhir" (TC-05)
  sesi valid + biometrik → verifikasi (3× gagal → form password, TC-07)
  sesi valid             → / Beranda (auto-login, TC-06)
```
Splash juga: rekam pengingat harian yang terlewat ke SCR-14 (`splash_screen.dart:107`) dan `kick()` sinkronisasi tanpa menunggu (`:118`).

**Register** — `auth_controller.dart:56`: validasi → salt + hash → simpan lokal → buat sesi → `POST /auth/register` bila online (gagal server **tidak** membatalkan registrasi — K-17).

**Login** — `auth_controller.dart:109`: verifikasi hash → buat sesi; pesan galat selalu umum *"Email atau password salah"* (TC-03), hitung percobaan.

**Logout (F-09)** — dialog di `app/shell.dart:36`: hapus token sesi + bersihkan state → SCR-01; DB ditutup splash saat menemukan sesi kosong; **data buku lokal tetap tersimpan (terenkripsi)**.

## 2. File kunci & komentar penjelas (`///`)

| File | Peran | Komentar penting |
|---|---|---|
| `lib/core/security/password_hasher.dart` | PBKDF2-HMAC-SHA256 | `:7` "PBKDF2 dipilih karena implementasi Dart murni → bisa diuji di host tanpa plugin native"; `:21` 210.000 iterasi (rekomendasi OWASP), statis non-konstan agar test boleh menurunkan; `:53` verifikasi *constant-time*; `:63` `kdf_params` JSON agar generasi hash bisa direproduksi; `:72` perbandingan hex tanpa short-circuit (antidesain timing attack) |
| `lib/core/security/session.dart` | Model sesi | `:4` "token acak tidak dapat ditebak + masa berlaku default 7 hari"; `:49` token 32 byte (64 hex) via CSPRNG OS |
| `lib/core/security/db_key_store.dart` | Kunci enkripsi DB | `:5` "kunci acak 256-bit… **tidak diturunkan dari password** agar login biometrik tetap dapat membuka database"; `:30` `Random.secure` (CSPRNG OS) |
| `lib/features/auth/auth_controller.dart` | State & aksi auth | `:28` hitung login gagal (workflow §3.2); `:31` hitung biometrik gagal (3× → form password, TC-07); `:224` `unawaitedServer` — panggilan server tanpa mengubah alur lokal |
| `lib/features/auth/splash_screen.dart` | SCR-01 splash | `:17` matriks 4 kemungkinan rute (lihat §1) |
| `lib/features/auth/auth_screen.dart` | SCR-01 form | `:13` tab Masuk/Daftar + `startMessage` (`'expired'`/`'biometric'`); `:42` tombol biometrik hanya bila aktif+didukung+ada sesi; `:491` indikator kekuatan password |
| `lib/features/auth/session_service.dart` | Cek/buat/hapus sesi | `:13` sesi kedaluwarsa **langsung dihapus** agar tidak dipakai lagi (TC-05) |
| `lib/features/auth/auth_store.dart` | Penyimpanan token | `:6` abstraksi → test memakai penyimpanan memori; `:21` produksi Keychain/Keystore — "dilarang memakai SharedPreferences biasa (workflow 4.3)" |
| `lib/features/auth/biometric_service.dart` | Pembungkus `local_auth` | `:4` semua metode "gagal dengan aman (`false`)" agar UI cukup menyembunyikan tombol; `:14` dukung biometrik **atau** kredensial layar (PIN/pola) |
| `lib/features/auth/user_repository.dart` | Tabel `users` | `:41` "password polos tidak pernah ditulis (TC-04)"; `:78` cari berdasarkan email **atau** nama ("Email / Username"); `:109`/`:147` update profil & ganti password (SCR-17, WF-04) |

**Backend (`backend/src/…`):**
- `controllers/auth.controller.js:17` — register balas **201** `{ token, expiresAt, user }`; `:51` login dengan pesan umum yang sama (mirip TC-03); `:85` logout menghapus token.
- `services/user.store.js:6` — "server menyimpan **hash miliknya sendiri** (PBKDF2 `node:crypto` + salt acak)… identik dengan skema klien"; `:126` sesi token acak 32 byte, 7 hari; `:140` sesi kedaluwarsa dihapus saat dicari.
- `middleware/auth.js:3` — semua endpoint kecuali register/login wajib `Authorization: Bearer <token>`.

## 3. API yang dipakai

| Endpoint | Pemanggil klien | Sifat |
|---|---|---|
| `POST /auth/register` | `auth_controller.dart:92` | best-effort (offline diabaikan, K-17) |
| `POST /auth/login` | `auth_controller.dart:133` | best-effort |
| `POST /auth/logout` | `auth_controller.dart:159` | `unawaitedServer` |

Detail kontrak di [`01_api_dan_backend.md`](01_api_dan_backend.md).

## 4. Test & keputusan

- **TC-01…TC-08** lulus di `test/auth_flow_test.dart` (register, validasi 8 karakter, pesan umum, hash tersimpan, sesi kedaluwarsa, biometrik sukses/gagal 3×, logout).
- Param KDF dikunci di `password_hasher_test` (PBKDF2-HMAC-SHA256, 210.000 iterasi).
- Keputusan: **K-13** (PBKDF2 bukan Argon2id), **K-14** (hash server di file JSON + sesi 7 hari), **K-15** (`FlutterFragmentActivity` untuk `local_auth`), **K-17** (POST auth best-effort), **K-8** (kunci DB terpisah dari password).

# Arsitektur Aplikasi & Alur Sistem — Penjelasan untuk Laporan

> Sumber: `lib/` (struktur nyata), `workflow_proyek.md` Bagian 3 (alur 3.1–3.8),
> `referensi_desain_ui_ux.md` Bagian 3 (navigasi), `keputusan.md` K-9.

## 1. Layering kode (`lib/`, 105 file Dart)

```
lib/
├── main.dart                 # entry: ProviderScope + StorylokaApp
├── app/                      # kerangka aplikasi
│   ├── app.dart              # tema + integrasi sensor cahaya + inisialisasi notifikasi
│   ├── router.dart           # seluruh rute go_router (lihat §3)
│   ├── shell.dart            # AppShell: Master Layout + bottom nav 5 slot
│   └── theme_mode_provider.dart  # mode tema Otomatis/Terang/Gelap (persist settings)
├── core/                     # fondasi lintas fitur (tanpa logika bisnis layar)
│   ├── db/        (14)       # schema + repository per tabel (SQLite/SQLCipher)
│   ├── models/    (9)        # model data murni (toRow/fromRow)
│   ├── network/   (7)        # ApiClient + sync/ai/rates/book_search/book_place
│   ├── security/  (3)        # password_hasher (PBKDF2), session, db_key_store
│   ├── notifications/ (2)    # NotificationService (abstraksi) + Coordinator (event)
│   ├── sensors/   (4)        # shake, auto-theme, stream sensor, discovery
│   ├── blockchain/(1)        # hash_chain (SHA-256)
│   ├── theme/, widgets/, utils/, location/  # design token, komponen reusable, util
└── features/                 # layar per fitur (ikut modul WF)
    auth/ · home/ · library/ · search/ · reading_session/ · book_detail/
    explore/ · ai/ · blockchain/ · game/ · profile/ · feedback/ · notifications/
```

**Aturan dependensi:** `features/*` → `core/*` → (package pihak ketiga).
`core/` tidak mengimpor `features/`. Repository murni (`core/db`) dipanggil lewat
provider Riverpod (`databaseProvider`) sehingga bisa disuntik saat test (K-16).

### Abstraksi = seam test (konsisten di seluruh lapisan)

| Abstraksi | Implementasi nyata | Fake di test |
|---|---|---|
| `NotificationService` | `flutter_local_notifications` | fake (TC-23) (K-32) |
| `PhotoPicker`/`ProfilePhotoStore` | `image_picker` | picker palsu (TC-10) (K-23) |
| `BiometricService` | `local_auth` | `_NoBiometric` (TC-06/07) |
| `CertificateShareService` | `share_plus` | tidak dipanggil (TC-26 pratinjau) (K-44) |
| `databaseProvider` | `sqflite_sqlcipher` | `sqflite_common_ffi` (K-7) |

## 2. Titik masuk & bootstrap

```dart
main() → WidgetsFlutterBinding.ensureInitialized()
       → runApp(ProviderScope(child: StorylokaApp()))   // lib/main.dart:8
```

`StorylokaApp` (`lib/app/app.dart:19`):
1. `watch(themeModeProvider)` → Otomatis/Terang/Gelap.
2. `init()` callback ketuk notifikasi (`NotificationCoordinator`, F-14).
3. `listen(luxProvider)` → `autoThemeProvider.feed(lux)` (sensor cahaya, WF-06);
   pindah mode manual → `reset()` keputusan sensor.
4. `MaterialApp.router` + `AppTheme.light()/dark()` (design token indigo/slate + Inter).

Splash (`features/auth/splash_screen.dart`) → cek sesi → rute `/auth` atau Beranda.

## 3. Peta rute (`lib/app/router.dart`)

| Rute | Layar | SCR | Bottom nav |
|---|---|---|---|
| `/splash` | SplashScreen | SCR-01 | sembunyi |
| `/auth` | AuthScreen (`extra`: `expired`/`biometric`) | SCR-01 | sembunyi |
| `/` | HomeScreen | SCR-02 | **tampil** |
| `/library` | LibraryScreen | SCR-03 | **tampil** |
| `/notifications` | NotificationsScreen | SCR-14 | **tampil** |
| `/explore` | ExploreScreen | SCR-04 | **tampil** |
| `/profil` | ProfileScreen | SCR-09 | **tampil** |
| `/kesan` | FeedbackScreen | SCR-10 | **tampil** |
| `/ai?book=` | AiAssistantScreen | SCR-05 | sembunyi |
| `/book/:id` | BookDetailScreen | SCR-06 | sembunyi |
| `/book/edit?id=/extra` | AddBookScreen | SCR-07 | sembunyi |
| `/search` | SearchScreen | SCR-08 | sembunyi |
| `/session?id=` | ReadingSessionScreen | SCR-15 | sembunyi |
| `/game` | GameScreen | SCR-16 | sembunyi |
| `/profile/edit` | EditProfileScreen | SCR-17 | sembunyi |

- Bottom nav = `StatefulShellRoute.indexedStack` 4 cabang (**Beranda · Explore · Profil · Kesan**);
  slot **Logout** adalah dialog konfirmasi, bukan rute (ketentuan desain Bagian 3.1).
- Layar fokus memakai `rootNavigatorKey` → bottom nav otomatis tersembunyi (Bagian 3.3, K-9).

## 4. Alur sistem (workflow Bagian 3) → kode

### 4.1 Start aplikasi & sesi (WF-02)
```
Splash → token ada & belum kedaluwarsa?
   Tidak → /auth (form login/register)
   Ya    → biometrik aktif? → verifikasi → sukses → SCR-02
                             → gagal 3× → form password
```
Kode: `features/auth/splash_screen.dart`, `session_service.dart`
(token di `flutter_secure_storage`, berlaku 7 hari — K-14), `biometric_service.dart`.

### 4.2 Register, login, logout (WF-02)
```
Register: validasi → salt + PBKDF2-HMAC-SHA256 (210.000 iterasi)
        → kunci DB acak 256-bit → secure storage → simpan user lokal
        → (+ POST /auth/register bila online, best-effort)
Login   : hash(input + salt) == tersimpan? → token + expiry → buka DB → SCR-02
        : tidak → "Email atau password salah" + hitung percobaan
Logout  : dialog → hapus token → tutup DB → bersihkan state → SCR-01
```
Kode: `features/auth/auth_controller.dart`, `core/security/password_hasher.dart`,
`db_key_store.dart` (kunci DB terpisah dari password — K-8), `user_repository.dart`.

### 4.3 Tambah buku & sesi membaca (WF-05)
```
Tambah: FAB SCR-03 / hasil pencarian online SCR-08 → SCR-07 → validasi
      → simpan SQLite + dirty=1
Sesi  : Mulai Baca → SCR-15 → simpan start_timestamp (epoch ms)
      → Selesai & Simpan → durasi = now − start_timestamp (timestamp, K-30)
      → update progres, jam total, streak, target → target tercapai? → notifikasi
      → halaman = total? → dialog "Tandai selesai?" → wajib ulasan & rating → WF-08
```
Kode: `features/library/add_book_screen.dart`, `reading_session/session_timer.dart`,
`book_detail/completion.dart`, `core/utils/reading_stats.dart`.

### 4.4 Blockchain — Proof of Reading (WF-08)
```
Ulasan disimpan → review_hash = SHA256(ulasan)
→ blok {idx, timestamp, book_id, review_hash, finished_date, previous_hash}
→ hash = SHA256(semua field) → insert tabel blocks (PK user_id+idx)
→ notifikasi "Sertifikat Diterbitkan" (rute /book/<id>)
Validasi: hitung ulang tiap blok + cek previous_hash → ✅ Valid / ❌ blok ke-n
```
Kode: `core/blockchain/hash_chain.dart`, `features/book_detail/completion.dart`
(hook dialog ulasan — K-43), `blockchain/blockchain_card.dart`, genesis = 64 nol.

### 4.5 AI / LLM (WF-07)
```
Prompt (+ konteks buku dari SCR-06) → POST /ai/* (Bearer)
→ backend → Gemini (key di server) → balasan + label "Dihasilkan AI"
→ error/kuota → pesan + Coba Lagi | offline → input mati + banner
Ringkasan dibaca dulu dari cache lokal (tabel ai_cache, key summary:<bookId>)
```
Kode: `core/network/ai_service.dart` (peta `AiFailure` — K-37),
`features/ai/ai_assistant_screen.dart`, `core/db/ai_cache_repository.dart` (K-38).

### 4.6 Sensor (WF-06)
```
Shake: magnitudo > 12 m/s² · 2 guncangan < 600 ms · debounce 1,5 dtk
     · layar SCR-02/04 · bukan sesi baca/kuis → haptic → buku acak Wishlist → modal
Cahaya: tema Otomatis? lux < 15 ≥ 2 dtk → gelap | lux > 40 ≥ 2 dtk → terang
       (zona 15–40 = histeresis; iOS ikuti sistem; mode manual sensor diabaikan)
```
Kode: `core/sensors/shake_detector.dart`, `auto_theme.dart`,
dipasang di `app.dart` (`ref.listen(luxProvider…)`).

### 4.7 Sinkronisasi (WF-03)
```
Perubahan lokal → dirty + updated_at → online?
   Ya  → POST /sync → snapshot penuh → last-write-wins → tandai synced
   Tidak → antrean; kick() backoff 5→15→60→300 dtk saat kembali online
```
Kode: `core/network/sync_service.dart`, `core/db/*_repository.dart`
(`pendingSync`), kontrak detail di [`01_api_dan_backend.md`](01_api_dan_backend.md).

### 4.8 Notifikasi (WF-06)
```
Atur jam Profil → jadwalkan pengingat harian lokal (timezone-aware)
Event (target/streak/sertifikat) → NotificationCoordinator.emitEvent
  → notifikasi sistem + tabel notifications (riwayat SCR-14)
Ketuk notifikasi → payload type|userId|rute → navigasi (SCR-06/15/14)
```
Kode: `core/notifications/notification_service.dart` (abstraksi, K-32),
`notification_coordinator.dart` (baca sinkron provider — K-35).

## 5. Alur navigasi utama (desain Bagian 3.4)

```
SCR-01 Splash/Login ──→ SCR-02 Beranda ──┬─→ SCR-03 Koleksi ─→ SCR-06 Detail
                                         │        └─→ SCR-07 Tambah/Edit
                                         ├─→ SCR-15 Sesi baca ─(selesai)→ ulasan → sertifikat
                                         ├─→ SCR-04 Explore (Peta · Konverter · Game→SCR-16)
                                         ├─→ SCR-09 Profil ─→ SCR-17 Edit profil
                                         ├─→ SCR-10 Kesan & Saran
                                         └─→ SCR-14 Notifikasi
Logout = dialog konfirmasi di slot kelima bottom nav
```

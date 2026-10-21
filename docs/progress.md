# Progres Pengerjaan Storyloka

> **File ini HANYA catatan kemajuan.** Aturan fitur/teknis tetap mengikuti
> tiga dokumen utama: `deskripsi_proyek.md` → `referensi_desain_ui_ux.md` →
> `workflow_proyek.md`. Bila ada selisih, dokumen utama yang berlaku.
>
> **Aturan pembaruan:** centang/ubah file ini **setiap akhir sesi kerja**
> atau setiap modul selesai, lalu commit bersama hasil kerja.

**Terakhir diperbarui:** 2026-10-21 · **Branch aktif:** `develop` (WF-01…WF-10 sudah di-merge)

## Status Ringkas

| Modul | Judul | Status | Target minggu |
|---|---|---|---|
| WF-01 | Setup & Fondasi | ✅ **Selesai** | 1 |
| WF-02 | Auth, Session, Biometrik, Logout | ✅ **Selesai** (sisa verifikasi HP — lihat bawah) | 2 |
| WF-03 | Data Lokal & Online | ✅ **Selesai** | 2 |
| WF-04 | Navigasi, Profil, Kesan | ✅ **Selesai** (sisa screenshot HP) | 2 |
| WF-05 | Library, Tracker, Pencarian, Konverter | ✅ **Selesai** (sisa screenshot HP) | 2–3 |
| WF-06 | Sensor, LBS, Notifikasi | ✅ **Selesai** (sisa screenshot HP) | 3 |
| WF-07 | AI / LLM (via backend) | ✅ **Selesai** (sisa screenshot HP) | 4 |
| WF-08 | Blockchain (hash chain) | ✅ **Selesai** (sisa screenshot HP) | 4 |
| WF-09 | Mini Game | ✅ **Selesai** (sisa screenshot HP) | 4 |
| WF-10 | Testing | ✅ **Selesai** (angka device: saat demo) | 5 |
| WF-11 | Laporan & Presentasi | 🟨 **Berjalan** (bahan penjelasan `docs/penjelasan/` siap; laporan/diagram/screenshot menyusul) | 5 |

> **Checklist DoD umum setiap modul** (workflow Bagian 5) — wajib lulus sebelum
> modul ditandai selesai:
> - [ ] Fitur sesuai `deskripsi_proyek.md` Bagian 5.
> - [ ] Tampilan sesuai SCR-xx di `referensi_desain_ui_ux.md`.
> - [ ] State kosong, loading, error/offline tertangani; Light & Dark benar.
> - [ ] Test case modul (workflow Bagian 6) dijalankan dan lulus.
> - [ ] Screenshot layar (Light & Dark) diambil untuk laporan.
> - [ ] Kode berkomentar pada logika penting.
> - [ ] Digabung ke `develop` tanpa error `flutter analyze`.

---

## ✅ WF-01 Setup & Fondasi — SELESAI (2026-10-10)

### Checklist WF-01
- [x] Flutter 3.47.7 + Android SDK terpasang; proyek `com.storyloka` Android + iOS.
- [x] Dependensi: riverpod 3, go_router 18, sqflite_sqlcipher, flutter_secure_storage, http, path_provider (+ sqflite_common_ffi untuk test host).
- [x] Design token (13 warna light/dark, spacing, radius) + font Inter 4 weight di-bundle + tema `AppTheme.light/dark`.
- [x] Widget dasar: StorylokaCard, StatusBadge, tombol, BookCover, BottomNavBar, Skeleton, EmptyState (SCR-12), ErrorState (SCR-13), TopBar, ScreenPlaceholder (SCR-11).
- [x] Navigasi: `StatefulShellRoute` 5 slot (Beranda · Explore · Profil · Kesan · Logout-dialog); rute SCR-01…SCR-17; layar fokus sembunyikan bottom nav.
- [x] Skema SQLite v1 (11 tabel, epoch ms UTC, flag `dirty`/`deleted`) + pembuka DB terenkripsi + kunci acak 256-bit di secure storage.
- [x] `ApiClient` + `GET /health` (base URL via `--dart-define`), status tampil di SCR-02.
- [x] Backend Express 5 (`backend/`): `/health`, 404 JSON, error handler, `.env.example`, test `node --test`.
- [x] Izin AndroidManifest + iOS Info.plist (teks Indonesia) sesuai workflow Bagian 4.4.
- [x] `docs/keputusan.md` (12 keputusan) + README (cara menjalankan app & backend).
- [x] `flutter analyze` bersih · `flutter test` 10/10 · `npm test` 2/2 · `flutter build apk --debug` sukses (183 MB).
- [x] Merge `feature/wf-01-setup` → `develop` (fast-forward, 7 commit).
- [ ] **Screenshot Light & Dark** semua layar awal — **belum dikerjakan**, butuh HP fisik; kerjakan bersama WF-02.

### File kunci yang dibuat
```
lib/app/            app.dart, router.dart, shell.dart, theme_mode_provider.dart
lib/core/theme/     app_colors, app_typography, app_dimensions, app_theme
lib/core/widgets/   11 file widget dasar + placeholder SCR-11/12/13
lib/core/db/        schema.dart (11 tabel), app_database.dart, database_provider.dart
lib/core/security/  db_key_store.dart (kunci acak 256-bit)
lib/core/network/   api_client.dart (/health)
lib/features/       14 layar placeholder SCR-01…SCR-17
backend/            Express 5 ESM + /health + test
test/               db_test, theme_test, widget_test (10 test)
docs/keputusan.md   12 keputusan teknis
```

---

## ✅ WF-02 Auth, Session, Biometrik, Logout — SELESAI (2026-10-10)

### Checklist WF-02
- [x] Layar Register & Login SCR-01 mengikuti Master Layout (tab Masuk/Daftar, toggle 👁 password, indikator kekuatan password, pesan galat bahasa Indonesia).
- [x] Hash password **PBKDF2-HMAC-SHA256 + salt acak 16 byte** (210k iterasi) — password polos tidak pernah ditulis ke mana pun (TC-04).
- [x] Register: validasi → tabel `users` → sesi 7 hari di Secure Storage → `POST /auth/register` bila online.
- [x] Login: verifikasi hash constant-time → token acak + expiry → SCR-02; gagal → "Email atau password salah" + hitung percobaan (TC-03).
- [x] Splash SCR-01: alur workflow §3.1 (token → biometrik aktif? 3× gagal → form password); sesi kedaluwarsa → dialog "Sesi berakhir, silakan masuk lagi" (TC-05).
- [x] Biometrik (`local_auth`): aktif/nonaktif dari Profil (wajib verifikasi saat menyalakan); perangkat tanpa biometrik → tombol disembunyikan.
- [x] Dialog Logout: hapus token (+ cabut sesi di server bila online) → tutup DB → bersih state → SCR-01 (TC-08).
- [x] Backend: `POST /auth/register`, `POST /auth/login`, `POST /auth/logout` (hash ulang `node:crypto`, Bearer token 7 hari, data di `backend/data/` yang di-gitignore).
- [x] Test: **TC-01…TC-08 lulus** (`test/auth_flow_test.dart`, biometrik memakai fake service).
- [x] `flutter analyze` bersih · `flutter test` 26/26 · `npm test` 9/9.
- [ ] Verifikasi perangkat: TC-06/07 dengan biometrik nyata + **screenshot Light & Dark SCR-01** — butuh HP fisik (dikerjakan bersama sisa screenshot WF-01).

### Catatan teknis (rincian di `docs/keputusan.md` 13–18; no. 18: proyek $0 / Gemini tier gratis)
- PBKDF2 (bukan Argon2id) agar bisa diuji di host; iterasi diturunkan sementara di unit test hash.
- Test widget wajib memakai `databaseFactoryFfiNoIsolate` — operasi ffi isolate tidak pernah selesai di zona fake-async `testWidgets`.
- Seed data test dilakukan via `tester.runAsync(...)` sebelum pump pertama (menghindari deadlock zona).

### File kunci yang dibuat
```
lib/features/auth/     auth_screen (SCR-01), splash_screen, auth_controller,
                       auth_store, session_service, user_repository, biometric_service
lib/core/security/     password_hasher, session
lib/core/db/           settings_repository
backend/src/           routes/auth.route, controllers/auth.controller,
                       services/user.store, middleware/auth
test/                  password_hasher_test, session_test, auth_flow_test (TC-01..08)
```

## ✅ WF-03 Data Lokal & Online — SELESAI (2026-10-10)

### Checklist WF-03
- [x] Model Dart 7 tabel inti (`lib/core/models/`): Book, ReadingSession, NoteQuote, Review, Block, FeedbackItem, AppSettings (`users` sudah ada; `notifications`/`rate_cache`/`game_scores` menyusul bersama fiturnya — keputusan 19).
- [x] Repository CRUD offline (`lib/core/db/`): `BookRepository` penuh (insert/update/softDelete/pendingSync/applyServer) + repo sesi/catatan/ulasan/blok/feedback; penanda `dirty` disetel otomatis di setiap perubahan lokal.
- [x] REST client umum: `ApiClient.postJson` dengan Bearer token, timeout, kode status ternormalisasi (`ApiResponse`; `-1` = offline).
- [x] `POST /sync` dua arah (workflow §3.7): kirim baris `dirty` + append-only + settings → server menerapkan **LWW `updated_at`** (tabel bervariabel waktu) & **insert-if-absent** (notes/reviews/blocks) → balasan snapshot penuh + `serverTime` → klien terapkan LWW → tandai `dirty=0`/`synced=1` → catat `settings.last_sync`.
- [x] Antrian otomatis: `kick()` saat splash masuk Beranda; gagal/offline → backoff 5→15→60→300 dtk sampai server menerima (antrean tidak hilang).
- [x] Backend: `POST /sync` (`sync.store.js` JSON per pengguna, `requireAuth`), terdaftar di `app.js`.
- [x] Skema naik **v2** (`settings.updated_at`, migrasi `ALTER TABLE`).
- [x] Test: **TC-29 lulus** (offline → antrean → online → terkirim & bersih) + 5 test CRUD buku + 5 test backend sync.
- [x] `flutter analyze` bersih · `flutter test` **35/35** · `npm test` **14/14**.
- [ ] Screenshot — tidak ada layar baru di WF-03 (tidak berlaku).

### Catatan teknis (rincian di `docs/keputusan.md` 19–22)
- Balasan `/sync` = snapshot penuh (idempoten, skala kecil); ID lokal dipertahankan → asumsi satu perangkat utama per pengguna.
- Deteksi online tanpa paket tambahan: kick + backoff (keputusan 22).
- Payload JSON server menyimpan data per pengguna di `backend/data/sync.json` (di-gitignore).

### File kunci yang dibuat
```
lib/core/models/       book, reading_session, note_quote, review, block,
                       feedback_item, app_settings
lib/core/db/           book_repository + 5 repository tabel lain
                       (settings_repository diperluas; schema v2)
lib/core/network/      api_client (postJson), sync_service (LWW + backoff)
backend/src/           routes/sync.route, controllers/sync.controller,
                       services/sync.store
test/                  book_repository_test, sync_test (TC-29)
```

## ✅ WF-04 Navigasi, Profil, Kesan — SELESAI (2026-10-10)

### Checklist WF-04
- [x] SCR-09 Profil: header berfoto (avatar → SCR-17), statistik ringkas (buku/jam/sertifikat/koin dari tabel lokal), keamanan & sesi (biometrik ON/OFF dengan verifikasi, enkripsi AES-256 aktif, "Sesi berlaku hingga"), notifikasi (pengingat harian + jam, target & streak), tema **Otomatis/Terang/Gelap** (segmented + persistensi `settings`, dimuat saat splash), "Sinkronkan Sekarang" + "Terakhir: …". Tidak ada tombol logout di sini.
- [x] SCR-17 Edit Profil: ganti foto (kamera/galeri via `image_picker`, disalin ke direktori dokumen), ubah nama/email, ganti password (verifikasi lama, hash baru) → Simpan.
- [x] Foto profil tampil di Profil **& Beranda** (avatar di top bar SCR-02, ketuk → Profil).
- [x] SCR-10 Kesan & Saran **untuk mata kuliah Pemrograman Aplikasi Mobile** (bukan penilaian aplikasi): dua kolom, validasi minimal satu terisi, isian terakhir tampil ulang & dapat diedit; simpan lokal (`synced=0`) + `POST /feedback` → tandai tersinkron; bila lokal kosong → `GET /feedback`.
- [x] Backend: `POST /feedback`, `GET /feedback` (`requireAuth`, LWW per pengguna di `sync.store`; feedback payload `/sync` kini juga key per pengguna).
- [x] Skema **v3** (`settings.streak_notify`, migrasi `ALTER TABLE`); model data di `deskripsi_proyek.md` ikut diperbarui.
- [x] Test: **TC-09, TC-10, TC-11 lulus** — `test/profile_test.dart` (5), `test/edit_profile_test.dart` (2), `test/feedback_flow_test.dart` (2); TC-09 memakai widget test 5 slot + dialog logout yang sudah ada.
- [x] `flutter analyze` bersih · `flutter test` **44/44** · `npm test` **19/19**.
- [ ] Screenshot Light & Dark SCR-09, 10, 17 (+ rekap screenshot WF-01/WF-02) — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 23–27)
- `PhotoPicker`/`ProfilePhotoStore` abstraksi → test TC-10 tanpa kamera/IO nyata; file uji PNG 1×1 dibuat di `setUp` (zona nyata) — IO async di dalam `testWidgets` menggantung di zona fake-async.
- Channel `local_auth` tidak pernah merespons di host → widget test menyuntikkan `BiometricService` palsu agar SCR-09 tidak menggantung.
- Tombol "SIMPAN / KIRIM" berada di bawah lipatan layar test → test memakai `ensureVisible` sebelum tap.

### File kunci yang dibuat
```
lib/features/profile/  profile_screen (SCR-09), edit_profile_screen (SCR-17),
                       profile_data, profile_stats, photo_service
lib/features/feedback/ feedback_screen (SCR-10)
lib/core/widgets/      profile_avatar (dipakai SCR-09 & top bar SCR-02)
lib/core/db/           schema v3 + settings_repository (tema/pengingat/streak)
                       feedback_repository (upsert per pengguna)
lib/core/network/      api_client.tryGetJson
backend/src/           routes/feedback.route, controllers/feedback.controller
test/                  profile_test, edit_profile_test (TC-10), feedback_flow_test (TC-11)
```

## ✅ WF-05 Library, Tracker, Pencarian, Konverter — SELESAI (2026-10-13)

### Checklist WF-05
- [x] SCR-03 Koleksi & Wishlist: daftar buku, filter chip status, FAB tambah.
- [x] SCR-07 Tambah/Edit Buku: validasi (judul wajib, halaman ≥ 1), sampul (galeri/kamera/manual).
- [x] SCR-06 Detail Buku: progres, total jam, streak, ulasan & rating wajib saat selesai → picu blockchain (WF-08).
- [x] SCR-15 Sesi Baca: **stopwatch dari timestamp** (akurat di latar belakang), input halaman terakhir, target bulanan.
- [x] SCR-08 Pencarian: lokal (judul/penulis/ISBN) + online (Google Books/Open Library) → pilih → form terisi.
- [x] Filter (genre, status, rating, tahun) & sort (terbaru, judul, rating).
- [x] SCR-02 Beranda: ringkasan (buku sedang dibaca, target, streak) dari data nyata.
- [x] Konverter: kurs IDR/USD/EUR/JPY (`GET /rates`, cache offline) + zona waktu WIB/WITA/WIT/London (DST).
- [x] Test: TC-12…TC-18 lulus (`test/library_flow_test.dart` TC-12…16, `test/converter_test.dart` TC-17…18).
- [x] `dart analyze lib test` bersih · `flutter test` **55/55** · `npm test` **21/21** (endpoint `GET /rates`).
- [ ] Screenshot Light & Dark SCR-02, 03, 04, 06, 07, 08, 15 — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 28–31)
- Stopwatch sesi memakai `SessionTimer` berbasis timestamp (jeda diakumulasi) — durasi tetap akurat saat aplikasi di latar belakang (TC-15).
- Semua `showModalBottomSheet` memakai `useRootNavigator: true` — sheet sebelumnya tersembunyi di balik bottom nav (Zona 4) sehingga tombol sheet bisa terkena tap nav.
- Kartu koleksi Beranda: tinggi carousel 300 dp agar cover 2:3 + 2 baris judul tidak overflow.
- Kurs dari `GET /rates` (tanpa API key) + cache SQLite `rate_cache`; label "Diperbarui …" memakai `fetchedAt`.

### File kunci yang dibuat
```
lib/features/library/        library_screen (SCR-03), library_data, filter_sheet,
                             book_tile (BookCard/BookTile), add_book_screen (SCR-07)
lib/features/search/         search_screen (SCR-08), search_data (hasil online)
lib/features/book_detail/    book_detail_screen (SCR-06), book_detail_data, completion
                             (dialog selesai + ulasan wajib → hook WF-08)
lib/features/reading_session/reading_session_screen (SCR-15), session_timer
lib/features/home/           home_screen (SCR-02), home_data (ReadingStats)
lib/features/explore/        explore_screen (segmen SCR-04), converter_panel (kurs + waktu)
lib/core/network/            book_search_service, rates_service
lib/core/utils/              currency, world_clock, reading_stats
lib/core/db/                 rate_cache_repository, book_repository (+filter), 
                             reading_session_repository (+furthestPage/totalDurationSec)
backend/src/                 routes/rates.route, controllers/rates.controller,
                             services/rate.store (fallback + TTL 6 jam)
test/                        library_flow_test (TC-12…16), converter_test (TC-17…18)
```

## ✅ WF-06 Sensor, LBS, Notifikasi — SELESAI (2026-10-14)

### Checklist WF-06
- [x] Shake (accelerometer): pilih buku acak dari Wishlist + haptic; ambang 12 m/s², jendela 600 ms, debounce 1500 ms (anti salah-picu).
- [x] Auto-theme sensor cahaya (Android): lux < 15 ≥ 2 dtk → gelap, > 40 → terang (histeresis); fallback tema sistem di iOS.
- [x] SCR-04 Peta: OpenStreetMap + Overpass tanpa API key; izin lokasi runtime + kartu ajakan bila ditolak; titik perpustakaan statis.
- [x] SCR-14 Notifikasi: pengingat harian dari SCR-09 (`scheduleDaily`, izin Android 13+), riwayat tercatat (`type|userId|rute`), ketuk notifikasi → catat + buka rute; "Tandai Semua Dibaca".
- [x] Test: **TC-19…TC-23 lulus** — `shake_test` (TC-19/20), `auto_theme_test` (TC-21), `lbs_test` (TC-22), `notification_test` (TC-23 + tombol Tandai Semua Dibaca; TC-23 lulus 3× berturut-turut).
- [x] `dart analyze lib test` bersih · `flutter test` **63/63** · `npm test` **21/21**.
- [ ] Screenshot Light & Dark SCR-04, 09 (toggle), 14 — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 32–35)
- Notifikasi sistem lewat abstraksi `NotificationService` + seam fake di test; payload `type|userId|rute` untuk riwayat + navigasi.
- `NotificationCoordinator` membaca provider sinkron (`AsyncValue.value`) — `await provider.future` dari `tester.runAsync` (zona nyata) menggantung pada Riverpod 3.4 + flutter_test; TC-23 menulis setelan via `SettingsRepository(db)` langsung.
- Android perlu `coreLibraryDesugaring` (`desugar_jdk_libs` 2.1.4) untuk `java.time` di `flutter_local_notifications`.

### File kunci yang dibuat
```
lib/core/sensors/            sensor_streams, shake_detector, auto_theme
lib/core/notifications/      notification_service (Android/iOS + fake host),
                             notification_coordinator (riwayat + jadwal + rute)
lib/features/notifications/  notifications_screen (SCR-14), notifications_data
lib/features/explore/        peta_panel (SCR-04 OSM + Overpass + izin lokasi)
lib/features/profile/        toggle pengingat → applyReminder (seam TC-23)
android/                     izin POST_NOTIFICATIONS/lokasi + desugaring
test/                        shake_test (TC-19…20), auto_theme_test (TC-21),
                             lbs_test (TC-22), notification_test (TC-23 + SCR-14)
```

## ✅ WF-07 AI / LLM via Backend — SELESAI (2026-10-14)

### Checklist WF-07
- [x] Backend proxy `POST /ai/chat`, `/ai/summarize`, `/ai/recommend` (requireAuth; Gemini; **API key hanya di `.env` server**); galat ternormalisasi `AI_QUOTA` (429), `AI_TIMEOUT` (504), `AI_UPSTREAM` (502), `AI_DISABLED` (503, tanpa key), `AI_MOCK=1` untuk mock.
- [x] SCR-05 AI Assistant: chat + konteks buku (query `?book=<id>` dari SCR-06), quick action Ringkasan/Buku Mirip/Jelaskan, state AI mengetik (tiga titik), galat + **Coba Lagi**, pesan kuota, offline → input dinonaktifkan + banner (TC-25), label **"Dihasilkan AI"**.
- [x] Ringkasan buku di SCR-06 (kartu ✨ AI: Ringkas dengan AI / Tanya AI); hasil di-cache lokal tabel `ai_cache`; label "Dihasilkan AI"; error → Coba Lagi.
- [x] Test: **TC-24, TC-25 lulus** (`test/ai_test.dart`: ringkasan + label + buka SCR-05 dari Tanya AI; offline → input mati + banner; gagal kirim → pesan + Coba Lagi).
- [x] `dart analyze lib test` bersih · `flutter test` **66/66** · `npm test` **26/26**.
- [ ] Screenshot Light & Dark SCR-05, SCR-06 (kartu AI) — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 36–38)
- Klien `AiService` memetakan `error.code` backend ke `AiFailure` (offline/quota/disabled/error) agar SCR-05/06 menampilkan pesan + aksi yang tepat.
- Ringkasan di-cache per buku (`summary:<bookId>`) — dibaca dulu, baru panggil backend; simpan best-effort.
- Kartu AI di SCR-06 berada di dalam `ListView` lazy: test harus `scrollUntilVisible` sebelum tap.

### File kunci yang dibuat
```
backend/src/                 services/ai.service (prompt sistem topik buku +
                             bahasa Indonesia, Gemini + timeout + mock),
                             controllers/ai.controller, routes/ai.route,
                             env (geminiModel/aiTimeoutMs/aiMock), app.js (/ai)
backend/test/                ai.test (5 test: auth + chat/summarize/recommend + 400)
lib/core/network/            ai_service (AiResult/AiFailure + chat/summarize/recommend)
lib/core/db/                 schema v4 (+tabel ai_cache), ai_cache_repository
lib/features/ai/             ai_assistant_screen (SCR-05 penuh)
lib/features/book_detail/    book_ai_card (kartu ✨ AI SCR-06),
                             router /ai?book=<id>
test/                        ai_test (TC-24, TC-25)
```

## ✅ WF-08 Blockchain (F-12 · SCR-06) — SELESAI (2026-10-17)

### Checklist WF-08
- [x] Hash chain SHA-256 **lokal** (bukan kripto/NFT): blok dibuat **otomatis di hook dialog ulasan** saat buku ditandai Selesai (`idx = max+1`, `previous_hash` = hash blok sebelumnya atau **64 nol (genesis)**, `review_hash` = SHA256(ulasan)); `hash` = SHA256 seluruh field dipisah `|`.
- [x] Validasi rantai (workflow §3.4): hitung ulang `hash` + cocokkan `previous_hash` + kelengkapan idx → **✅ Valid** / **❌ Tidak Valid (blok ke-n)** yang menunjuk blok bermasalah.
- [x] Kartu 🛡 **Blockchain di SCR-06** (hanya status Selesai): badge `success-500` "Terverifikasi (Hash Chain Lokal)", nomor blok, hash terpotong (`8f4a…e91c`), `previous_hash`, tanggal selesai, tombol **Validasi Rantai** + **Bagikan Sertifikat**.
- [x] Sertifikat: dialog pratinjau (`RepaintBoundary.toImage` → PNG) → **Bagikan Gambar** via `share_plus` (abstraksi `CertificateShareService`).
- [x] Notifikasi **"Sertifikat Diterbitkan"** (`type=certificate`, tanpa dedupe, rute `/book/<id>`) → riwayat SCR-14 + sistem.
- [x] Statistik SCR-09 "Sertifikat" otomatis benar (menghitung tabel `blocks`); blok ikut `POST /sync` sebagai *anchor* server (Bagian 5.7 mitigasi).
- [x] Test: **TC-26, TC-27 lulus** (+3 test unit `HashChain` + 1 pratinjau sertifikat) — `test/blockchain_test.dart`.
- [x] `dart analyze lib test` bersih · `flutter test` **73/73** · `npm test` **26/26**.
- [ ] Screenshot Light & Dark kartu blockchain + sertifikat di SCR-06 — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 42–45)
- SHA-256 memakai **paket `crypto`** (sinkron) — `cryptography` hanya punya `hash()` async; `crypto` dijadikan dependensi langsung sesuai tech stack deskripsi Bagian 3.
- Tangkap PNG **sebelum dialog ditutup** (widget `Offstage` tidak dilukis → `toImage` gagal); seam `CertificateShareService` agar test tanpa platform share.
- Judul kartu ulasan & judul dialog di SCR-06 sama ("Ulasan & Rating") → test harus mencari via descendant `AlertDialog`.

### File kunci yang dibuat
```
lib/core/blockchain/          hash_chain.dart (sha256Hex, buildBlock, validate,
                              ChainValidation, shortHash)
lib/core/db/                 block_repository (+lastByUser, +findByBook)
lib/features/blockchain/     blockchain_card (kartu SCR-06 + validasi + share),
                             reading_certificate (widget sertifikat),
                             certificate_share_service (share_plus + seam)
lib/features/book_detail/    completion (+blok +notifikasi sertifikat),
                             book_detail_data (+field block),
                             book_detail_screen (placeholder → BlockchainCard)
test/                        blockchain_test (unit HashChain, TC-26, TC-27,
                              pratinjau sertifikat)
pubspec.yaml                 +share_plus 13, +crypto 3 (dependensi langsung)
```

## ✅ WF-09 Mini Game (F-13 · SCR-16) — SELESAI (2026-10-17)

### Checklist WF-09
- [x] **Kuis literasi 10 soal**: bank lokal 31 soal (tebak penulis/judul/genre, offline) + soal dari koleksi pengguna ("Siapa penulis X di koleksimu?"); ronde & posisi jawaban diacak; timer 15 dtk/soal berbasis timestamp — habis = salah (deskripsi Bagian 5.8).
- [x] **Skor & koin tersimpan di `game_scores`**: +100 poin & +10 koin per benar; setiap ronde selesai menambah baris; skor tertinggi (`MAX`) & total koin (`SUM`) tampil di kartu segmen Game SCR-04 dan intro SCR-16; koin ikut statistik Profil SCR-09 (sudah `SUM`).
- [x] **SCR-16** tanpa bottom nav (rute fokus): progress (n/10), timer lingkaran, kartu pertanyaan, 4 pilihan A–D; benar → `success-500`, salah/timeout → `danger500` + tampil jawaban benar; hasil = skor, koin, rekor (+ "Rekor Baru!"), tombol **Main Lagi / Kembali**.
- [x] Segmen Game SCR-04: kartu "Book Trivia Challenge" + rekor + koin → **Mainkan** → `/game`; shake tetap nonaktif di SCR-16 (hanya aktif di SCR-02/04).
- [x] Test: **TC-28 lulus** (+ unit `QuestionBank`/`QuizSession`, timeout, Main Lagi, segmen Game) — `test/game_test.dart` (10 test).
- [x] `dart analyze lib test` bersih · `flutter test` **83/83** · `npm test` **26/26**.
- [ ] Screenshot Light & Dark SCR-16 + segmen Game SCR-04 — butuh HP fisik.

### Catatan teknis (rincian di `docs/keputusan.md` 46–49)
- Skor/koin: 100 poin & 10 koin per benar (keputusan 46); timer timestamp + render periodik 200 ms (47); bank lokal + koleksi dengan opsi generik (48).
- Haptic di SCR-16 `unawaited(...catchError)` (49) — kanal platform tak merespons di host test, `await` akan menggantung di zona fake-async (pelajaran dari `local_auth` WF-04).
- `GameScreen` menerima `questionSeconds` & `questionsOverride` untuk test deterministik; test menjawab lewat key `answer-*` dengan pompa frame terbatas (timer periodik → `pumpAndSettle` tidak akan pernah selesai, pola SCR-15).

### File kunci yang dibuat
```
lib/features/game/         question_bank (bank 31 soal + koleksi), quiz_session
                           (mesin skor/feedback), game_screen (SCR-16 penuh)
lib/core/db/               game_score_repository (save/best/totalCoins/playCount)
lib/features/explore/      explore_screen (+gameSummaryProvider, kartu rekor & koin)
lib/app/router.dart        import rute /game → features/game/game_screen.dart
test/                      game_test (TC-28 + 9 test unit/widget)
dihapus: lib/features/explore/game_screen.dart (placeholder WF-01)
```

## ✅ WF-10 Testing (semua modul) — SELESAI (2026-10-17)

- [x] Jalankan seluruh **TC-01…TC-29 → semua LULUS** (kolom Status Bagian 6 di `workflow_proyek.md` sudah diisi ☑); setiap TC punya test otomatis bernama mengandung ID TC-nya.
- [x] Performance (host, `test/performance_test.dart`): PBKDF2 210k hash+verify ≈ **11,9 dtk** · insert 1 buku **95 ms** · query 200 buku **45 ms** · filter genre **6 ms** · buildRound **56 ms** · splash → Beranda **6,9 dtk**.
- [x] Regresi: `dart analyze lib test` bersih · `flutter test` **88/88** · `npm test` **26/26** — bug kritis nol.
- [ ] Angka device (waktu start di HP, respons AI, pemakaian memori) diukur & dicatat saat demo/screenshot (butuh HP + backend jaringan).

### Catatan teknis (keputusan 50–51)
- Performance diukur sebagai test host biasa (Stopwatch + `print` `[perf]`), **bukan** integration_test/device; seed 200 buku via **satu transaksi** karena insert baris-demi-baris autocommit lambat (23 dtk/200 — bukan alur nyata app). (keputusan 50)
- Status TC ditandai dari test otomatis; TC sensor (biometrik/shake/cahaya/GPS/notifikasi) lulus via seam simulasi — verifikasi manual HP saat demo. (keputusan 51)

### File kunci yang dibuat
```
test/performance_test.dart   [perf] PBKDF2, 200 buku, buildRound, bootstrap
docs/workflow_proyek.md      Bagian 6: Status ☑ ×29 + catatan performa
```

## 🟨 WF-11 Laporan & Presentasi

- [x] **Bahan penjelasan source code** (materi Bagian Implementasi): 12 file di `docs/penjelasan/` (lihat catatan 2026-10-17 di bawah).
- [ ] Laporan 7 bagian (Cover…Lembar Evaluasi) sesuai deskripsi Bagian 6.
- [ ] Screenshot semua SCR-01…SCR-17 (Light & Dark) untuk Bab Implementasi.
- [ ] Diagram: Use Case, ERD, Class Diagram, Flow (dari workflow Bagian 3).
- [ ] Demo alur lengkap: login biometrik → tambah buku → sesi baca → selesai + ulasan → blockchain → AI → shake → LBS → konverter → kuis → kesan → logout.
- [ ] Cadangan: video demo, APK/IPA siap, laporan tercetak + halaman pengesahan sebelum UAS.

---

## 📱 2026-10-16 — Build & instal APK ke HP fisik (persiapan screenshot)

- **Build Android sempat rusak sejak WF-06**: `light_sensor` 3.0.2 memanggil `jcenter()` (dihapus di Gradle 9) → `assembleRelease` gagal. Diperbaiki dengan **vendor paket ke `packages/light_sensor`** + `build.gradle` diperbaiki (keputusan **40**); `packages/**` dikeluarkan dari analyzer.
- **APK release arm64** dibuat dengan `--dart-define=API_BASE_URL=http://192.168.1.71:3000` → **35,6 MB** (vs debug 191 MB) dan **terpasang di HP Realme C2** (`com.storyloka.storyloka`) via `adb install` (keputusan **41**); aplikasi sudah dibuka di HP.
- Backend Express dijalankan di PC (`node src/server.js`), `/health` OK di `0.0.0.0:3000`.
- **Belum selesai:** aturan firewall inbound TCP 3000 butuh hak admin (perintah di komentar sesi ini) supaya HP bisa mengakses backend; screenshot Light & Dark semua SCR tetap menunggu HP (mulai WF-01/WF-02).

---

## ⛓ 2026-10-17 — WF-08 Blockchain (Proof of Reading) selesai

- `HashChain` (`lib/core/blockchain/`): SHA-256 via paket **`crypto`** (sinkron — `cryptography` hanya async), `buildBlock` (genesis 64 nol), `validate` (idx urut + `previous_hash` + hitung ulang hash → `ChainValidation.brokenIndex`).
- Hook di dialog ulasan (`completion.dart`): buku selesai → blok dibuat → notifikasi **"Sertifikat Diterbitkan"** (riwayat SCR-14, rute `/book/<id>`).
- Kartu blockchain menggantikan placeholder di SCR-06: ringkas Blok #n · hash terpotong · tanggal; **Validasi Rantai** → ✅ Valid / ❌ Tidak Valid (blok ke-n); **Bagikan Sertifikat** → dialog pratinjau → PNG (`RepaintBoundary`) → `share_plus`.
- Tambah dependensi: `share_plus` 13.3.1 + `crypto` 3.0.7 (keputusan **42–45**).
- **Verifikasi:** `dart analyze lib test` bersih · `flutter test` **73/73** (TC-26, TC-27 + 5 test baru) · `npm test` **26/26**.
- Screenshot kartu blockchain/sertifikat masih menunggu HP fisik (bersama sisa screenshot WF-01…WF-07).

---

## 🎮 2026-10-17 — WF-09 Mini Game (Book Trivia) selesai

- **Sesi WF-09 sebelumnya berhenti/error sebelum commit apa pun** (working tree bersih, tidak ada cabang) → dikerjakan ulang penuh di `feature/wf-09-game`.
- `lib/features/game/`: `question_bank` (31 soal lokal + generator soal koleksi), `quiz_session` (mesin skor/feedback/timeout), `game_screen` (SCR-16 penuh: progress n/10, timer lingkaran 15 dtk, 4 pilihan A–D, benar `success-500` / salah `danger-500` + koreksi, hasil Main Lagi/Kembali).
- `GameScoreRepository` (`lib/core/db/`): `save` per ronde, `bestScore`, `totalCoins`, `playCount`; skema `game_scores` sudah ada sejak WF-01 — tanpa migrasi.
- Segmen Game SCR-04 kini menampilkan rekor & koin (`gameSummaryProvider`) → **Mainkan** → `/game`.
- **Verifikasi:** `dart analyze lib test` bersih · `flutter test` **83/83** (TC-28 + 9 test baru) · `npm test` **26/26**.
- Keputusan **46–49** (formula skor/koin, timer timestamp, bank soal, haptic fire-and-forget).
- **Berikutnya:** WF-10 Testing (TC-01…TC-29, performance, regresi).
- Screenshot SCR-16 & segmen Game masih menunggu HP fisik (bersama sisa screenshot WF-01…WF-08).

---

## 🧪 2026-10-17 — WF-10 Testing selesai

- **TC-01…TC-29 semua lulus** (88 test Flutter — tiap TC punya test bernama ID TC) + **26** backend; kolom Status Bagian 6 `workflow_proyek.md` diisi ☑ + catatan verifikasi manual HP.
- **Performance host** (`test/performance_test.dart`, keputusan **50**): PBKDF2 210k hash+verify 11,9 dtk · insert 1 buku 95 ms · query 200 buku 45 ms · filter 6 ms · buildRound 56 ms · splash→Beranda 6,9 dtk.
- **Verifikasi:** `dart analyze lib test` bersih · `flutter test` **88/88** · `npm test` **26/26**; bug kritis nol.
- Keputusan **50–51** (metrik host vs device; status TC dari test otomatis).
- **Berikutnya:** WF-11 Laporan & Presentasi (laporan 7 bagian, screenshot SCR-01…17 Light & Dark, diagram, demo) — **butuh HP fisik**.

---

## 📚 2026-10-17 — WF-11 bahan penjelasan source code (`docs/penjelasan/`) selesai

- **12 file** di `docs/penjelasan/` (cabang `feature/wf-11-laporan`): `00_tech_stack` (teknologi + keputusan K-xx), `01_api_dan_backend` (11 endpoint + pemanggil `file:baris`), `02_arsitektur_alur` (layering `lib/`, 15 rute go_router, alur §4.1–4.8), `10_wf02`…`17_wf09` (**8 file per modul** WF-02…WF-09: alur → tabel file kunci + kutipan komentar `file:baris` → API → test & keputusan), `20_komentar_per_file` (**indeks 145 file**: 103 Dart + 21 test + 21 backend).
- Sumber: ekstraksi 569 blok komentar `///` (lib/) + komentar `//` backend; **126 rujukan `file:baris` diverifikasi** (0 meleset), link antar-file & path disilang (0 rusak/ hilang).
- Perbaikan fakta saat cek silang: referensi `library_data.dart:21` (bukan `:32`) dan jumlah bank soal **31** (bukan 30 — `keputusan.md` K-48 & entri WF-09 di file ini ikut diperbarui).
- **Berikutnya:** laporan 7 bagian, screenshot SCR-01…17 Light & Dark, diagram, demo — **butuh HP fisik**.

---

## 🎯 2026-10-20 — Mode demo (akun berisi data) + instal APK ke HP

- **Mode demo** (keputusan **52**): `--dart-define=DEMO_MODE=true` menampilkan tombol **"Masuk Demo (data contoh)"** di SCR-01 → `DemoSeeder` (`lib/features/auth/demo_seed.dart`, via `AuthController.loginDemo`) membuat akun **demo@storyloka.app / Demo1234!** lalu menanam data contoh: **11 buku** (5 selesai, 2 sedang dibaca, 2 wishlist, 2 belum dibaca; 2 selesai bulan ini → target bulanan 4 sebagian), **sesi baca 6 hari berturut** (streak), catatan & kutipan, **5 ulasan + rantai blok SHA-256 valid** (genesis → 5 blok), pengaturan pengingat 20:00, kesan & saran contoh, **3 ronde skor game** (rekor 1000 / 245 koin), 2 riwayat notifikasi. **Idempoten** — buka lagi tidak menggandakan data; build biasa tanpa flag tidak memakai tombol ini.
- **Verifikasi:** `flutter analyze` bersih · `flutter test` **91/91** (3 test baru `test/demo_seed_test.dart`: kelengkapan, idempoten, validitas rantai).
- **APK release arm64** (35,8 MB) dibuat dengan `--dart-define=DEMO_MODE=true --dart-define=API_BASE_URL=http://192.168.1.71:3000` (keputusan **53**) → **terpasang di HP Realme C2** via `adb install -r` (23:09) dan diluncurkan — proses `com.storyloka.storyloka` berjalan, logcat tanpa crash.
- Backend `node src/server.js` jalan di PC; **HP berhasil mengakses** `http://192.168.1.71:3000/health` (curl dari device sukses — akses jaringan HP→PC tidak lagi terblokir, berbeda catatan 2026-10-16).
- **Belum diverifikasi visual:** screenshot `screencap` hitam karena layar kunci HP (PIN/pola pengguna); verifikasi UI via `uiautomator dump` hanya sampai jendela aplikasi. **Langkah manual:** buka HP → SCR-01 → tap **"Masuk Demo (data contoh)"** → Beranda/koleksi terisi.
- Screenshot Light & Dark SCR-01…17 (WF-11) tetap menunggu HP terbuka.

---

## 🌐 2026-10-21 — Mode online diperbaiki (token server) + bug games & peta

- **Mode online** (keputusan **54**): token sesi server kini disimpan dari balasan `POST /auth/register|login` (`AuthStore.writeServerToken`, key `storyloka.serverToken`) dan dipakai **6 titik pemakaian** (`/ai`, `/rates`×2, `/sync`, `/feedback`×2, kartu AI, layar AI) via helper `onlineToken` = **server ?? lokal**; register 409 (akun sudah ada) otomatis diulang `/auth/login`. **Akar gejala "Galat sesi" di HP:** app mengirim token lokal, backend memvalidasi sesi buatannya sendiri → 401. Panggilan tetap fire-and-forget (offline-first utuh).
- **Config 1 file** (keputusan **55**): `lib/core/config/app_config.dart` (`AppConfig.apiBaseUrl` dari `--dart-define=API_BASE_URL`); clone di perangkat lain cukup ubah 1 baris → build. README bagian "Mode online" diperbarui.
- **Bug games** (SCR-04 + SCR-16): (a) `_finishRound()` kini `ref.invalidate(gameSummaryProvider)` + `profileStatsProvider` — rekor/koin segmen Game & Profil langsung segar setelah ronde (tanpa kill app); (b) `buildRound` kini **shuffle opsi jawaban** + hitung ulang `correctIndex` (sebelumnya selalu A) — test shuffle di `test/game_test.dart` (4 seed).
- **Ketahanan peta** (keputusan **56**): state gagal dipisah (`gpsError` vs `error`) + tombol coba-lagi masing-masing, GPS timeout 20 dtk, Overpass **utama → mirror Kumi**, cache `places_cache.json` + label "Menampilkan data offline".
- **Toolchain Android dikembalikan AGP 9.1.0/Gradle 9.3.1** (keputusan **57**) — commit anggota "add web support" 8a7fd9c menurunkan ke AGP 8.11.1 → `flutter build apk` gagal di `:image_picker_android`; web tidak terpengaruh.
- **Verifikasi:** `flutter test` **100/100** (9 test baru `test/online_mode_test.dart`: token server, fallback 409, Overpass+cache, invalidate rekor) · `flutter analyze` bersih · APK release arm64 **37,5 MB** (`DEMO_MODE=true`, `API_BASE_URL=http://192.168.1.71:3000`) **terpasang & diluncurkan** di HP Realme C2 (MainActivity top-most, tanpa crash).
- **Tertunda (butuh user):** verifikasi interaktif di HP (kurs, peta, skor game, AI) — layar terkunci PIN/pola; **AI butuh `backend/.env` isi `GEMINI_API_KEY`** (file belum ada → backend membalas "Layanan AI belum tersedia"); hosting cloud menunggu keputusan anggota (keputusan tetap 53+54).

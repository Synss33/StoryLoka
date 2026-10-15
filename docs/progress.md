# Progres Pengerjaan Storyloka

> **File ini HANYA catatan kemajuan.** Aturan fitur/teknis tetap mengikuti
> tiga dokumen utama: `deskripsi_proyek.md` → `referensi_desain_ui_ux.md` →
> `workflow_proyek.md`. Bila ada selisih, dokumen utama yang berlaku.
>
> **Aturan pembaruan:** centang/ubah file ini **setiap akhir sesi kerja**
> atau setiap modul selesai, lalu commit bersama hasil kerja.

**Terakhir diperbarui:** 2026-10-14 · **Branch aktif:** `feature/wf-07-ai` (WF-01…WF-06 sudah di-merge ke `develop` @ `1bca365`)

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
| WF-08 | Blockchain (hash chain) | ⬜ Belum | 4 |
| WF-09 | Mini Game | ⬜ Belum | 4 |
| WF-10 | Testing | ⬜ Belum | 5 |
| WF-11 | Laporan & Presentasi | ⬜ Belum | 5 |

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

## ⬜ WF-08 Blockchain (F-12 · SCR-06)

- [ ] Hash chain SHA-256 **lokal** (bukan kripto/NFT): blok dibuat saat buku selesai (bersama ulasan).
- [ ] Validasi rantai (blok rusak → "Tidak Valid" + menunjuk blok bermasalah).
- [ ] Tampilan sertifikat/rantai di SCR-06.
- [ ] Test: TC-26, TC-27.

## ⬜ WF-09 Mini Game (F-13 · SCR-16)

- [ ] Kuis literasi 10 soal (bawaan lokal), timer opsional.
- [ ] Skor & koin tersimpan di `game_scores`; tampil di SCR-16.
- [ ] Test: TC-28.

## ⬜ WF-10 Testing (semua modul)

- [ ] Jalankan seluruh TC-01…TC-29, isi kolom Status di workflow Bagian 6.
- [ ] Performance: waktu start, muat 200 buku, respons AI, memori — dicatat.
- [ ] Regresi: `flutter analyze`, `flutter test`, `npm test` tetap hijau; bug kritis nol.

## ⬜ WF-11 Laporan & Presentasi

- [ ] Laporan 7 bagian (Cover…Lembar Evaluasi) sesuai deskripsi Bagian 6.
- [ ] Screenshot semua SCR-01…SCR-17 (Light & Dark) untuk Bab Implementasi.
- [ ] Diagram: Use Case, ERD, Class Diagram, Flow (dari workflow Bagian 3).
- [ ] Demo alur lengkap: login biometrik → tambah buku → sesi baca → selesai + ulasan → blockchain → AI → shake → LBS → konverter → kuis → kesan → logout.
- [ ] Cadangan: video demo, APK/IPA siap, laporan tercetak + halaman pengesahan sebelum UAS.

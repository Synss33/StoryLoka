# 20 — Indeks Komentar Per File

Indeks seluruh source code proyek Storyloka: **peran satu kalimat + komentar dokumen utama** (`///` Dart / `//` JavaScript) beserta lokasi `file:baris`. Ini pelengkap 8 dokumen per-WF ([`10_wf02_auth.md`](10_wf02_auth.md)…[`17_wf09_game.md`](17_wf09_game.md)) — kutipan komentar lengkap per modul ada di dokumen masing-masing.

**Cakupan:** 103 file Dart (`lib/`), 21 file uji (`test/`), 21 file JavaScript (`backend/src/`) — total **145 file**.

**Sumber:** ekstraksi komentar `///` dari `lib/` (569 blok komentar, 102 dari 103 file) dan komentar dari `backend/src/` (52 blok). `lib/main.dart` adalah satu-satunya file tanpa komentar (9 baris).

## A. `lib/app/` — kerangka aplikasi (4 file)

| File | Peran | Komentar utama |
|---|---|---|
| `app/app.dart` | Widget akar: tema, mode tema, sinkronisasi awal | `:12` "Widget aplikasi Storyloka: memasang tema (terang/gelap), state mode tema…" |
| `app/router.dart` | Peta rute go_router (shell + layar fokus) | `:26` "Peta rute Storyloka (dokumen desain Bagian 3.2-3.4)"; `:22` navigator akar |
| `app/shell.dart` | Wadah 4 tab + slot Logout (Zona 4) | `:9` "Zona 4 Master Layout: wadah 4 tab (Beranda, Explore, Profil, Kesan) + slot Logout"; `:36` "Dialog konfirmasi Logout (F-09)" |
| `app/theme_mode_provider.dart` | State mode tema (auto/terang/gelap) | `:6` "Mode tema Storyloka — dokumen desain Bagian 1.5" |

## B. `lib/core/` — lapisan inti (58 file)

### B1. `core/blockchain/` (1)

| File | Peran | Komentar utama |
|---|---|---|
| `hash_chain.dart` | Bangun & validasi rantai SHA-256 | `:17` "Hash chain SHA-256 lokal 'Proof of Reading' (F-12 / Bagian 5.7)"; `:29` genesis 64 nol; `:81` "Validasi rantai (workflow Bagian 3.4)" |

### B2. `core/db/` — akses SQLite lokal (14)

| File | Peran | Komentar utama |
|---|---|---|
| `ai_cache_repository.dart` | Tabel `ai_cache` (ringkasan AI per buku) | `:6` "Akses tabel `ai_cache` (F-11 — Bagian 5.6)"; `:13` upsert per key |
| `app_database.dart` | Pembuka database terenkripsi | `:5` "Pembuka database terenkripsi Storyloka" |
| `block_repository.dart` | Tabel `blocks` (hash chain) | `:7` "Akses tabel `blocks` — hash chain lokal 'Proof of Reading' (Bagian 5.7)" |
| `book_repository.dart` | CRUD buku + dirty/sinkronisasi | `:7` "CRUD buku offline pada tabel `books` (F-04, deskripsi Bagian 5.2)" |
| `database_provider.dart` | Riverpod provider pembuka DB | `:10` "Membuka database terenkripsi… saat aplikasi pertama berjalan" |
| `feedback_repository.dart` | Tabel `feedback` + antrean kirim | `:7` "Akses tabel `feedback` (kesan & saran — SCR-10)"; `:25` upsert; `:60` antrean `synced = 0` |
| `game_score_repository.dart` | Tabel `game_scores` (skor/koin kuis) | `:33` "Akses tabel `game_scores` — mini game Book Trivia (F-13 / WF-09)… MAX(score) = rekor, SUM(coins) = statistik koin" |
| `note_quote_repository.dart` | Tabel `notes_quotes` (append-only) | `:7` "Akses tabel `notes_quotes` (F-04). Append-only…" |
| `notification_repository.dart` | Riwayat notifikasi lokal (SCR-14) | `:7` "Akses tabel `notifications` — riwayat pengingat/target/streak/sertifikat" |
| `rate_cache_repository.dart` | Cache kurs (tabel `rate_cache`) | `:7` "Akses tabel `rate_cache` (F-17 — Bagian 5.12): kurs terakhir" |
| `reading_session_repository.dart` | Sesi baca + progres/total durasi | `:7` "Akses tabel `reading_sessions` (F-04; dipakai WF-05 & sinkron WF-03)" |
| `review_repository.dart` | Ulasan (append-only) | `:7` "Akses tabel `reviews` (F-04). Append-only — ulasan dibuat sekali…" |
| `schema.dart` | 12 tabel + migrasi v1–v4 | `:3` "Skema database lokal Storyloka v1 — dokumen deskripsi proyek Bagian 5.2"; `:12` aturan versi |
| `settings_repository.dart` | Tabel `settings` lintas modul | `:7` "Akses tabel `settings` (WF-02: `biometric_enabled`; WF-03: `last_sync`; …)" |

### B3. `core/location/` (1)

| File | Peran | Komentar utama |
|---|---|---|
| `location_service.dart` | Akses GPS/izin (Geolocator, disuntikkan) | `:5` "Akses lokasi perangkat yang dapat disuntikkan untuk pengujian" |

### B4. `core/models/` — model data murni (8)

| File | Peran | Komentar utama |
|---|---|---|
| `app_notification.dart` | Baris riwayat notifikasi | `:1` "Riwayat notifikasi — tabel `notifications` (SCR-14 / F-14 / WF-06)" |
| `app_settings.dart` | Baris pengaturan pengguna | `:1` "Baris pengaturan pengguna (tabel `settings`)" |
| `block.dart` | Blok hash chain | `:1` "Blok hash chain 'Proof of Reading' (tabel `blocks`, Bagian 5.7)" |
| `book.dart` | Model buku + payload sync | `:1` "Model buku (tabel `books` — deskripsi Bagian 5.2)"; `:72` payload `POST /sync` |
| `feedback_item.dart` | Baris kesan & saran | `:1` "Kesan & saran mata kuliah Pemrograman Aplikasi Mobile (tabel `feedback`)" |
| `note_quote.dart` | Catatan/kutipan | `:1` "Catatan / kutipan (tabel `notes_quotes`, CHECK type IN ('note','quote'))" |
| `reading_session.dart` | Sesi membaca | `:1` "Sesi membaca (tabel `reading_sessions`)" |
| `review.dart` | Ulasan buku | `:1` "Ulasan buku (tabel `reviews`). Append-only…" |

### B5. `core/network/` — REST & layanan online (6)

| File | Peran | Komentar utama |
|---|---|---|
| `ai_service.dart` | Klien `POST /ai/*` + `AiFailure` | `:36` "Klien proxy AI (F-11 / WF-07): `POST /ai/*` ke backend, API key tetap di server"; `:6` enum kegagalan |
| `api_client.dart` | Klien REST dasar (getHealth/tryPost/post/get) | `:14` "Klien REST API dasar"; `:30` default loopback emulator |
| `book_place_service.dart` | Cari toko buku/perpustakaan (Overpass) | `:8` "Tempat terkait bacaan di sekitar pengguna — toko buku & perpustakaan"; `:56` Haversine |
| `book_search_service.dart` | Pencarian online Google Books/Open Library | `:36` "Klien pencarian buku online tanpa API key (keputusan 18: proyek $0)" |
| `rates_service.dart` | `GET /rates` + fallback cache | `:18` "Pengambil kurs (F-17): `GET /rates` dari backend, hasil terakhir…" |
| `sync_service.dart` | Sinkronisasi dua arah + backoff | `:25` "Sinkronisasi dua arah (F-05, alur workflow §3.7)" |

### B6. `core/notifications/` (2)

| File | Peran | Komentar utama |
|---|---|---|
| `notification_coordinator.dart` | Penghubung notifikasi → riwayat → rute | `:15` "Penghubung notifikasi sistem → riwayat lokal → navigasi (F-14 / WF-06)"; `:110` event + dedupe |
| `notification_service.dart` | Layanan notifikasi disuntikkan | `:27` "Layanan notifikasi sistem yang dapat disuntikkan (F-14 / WF-06) — pengujian TC-23 menyuntikkan tiruan"; `:54` implementasi `flutter_local_notifications` |

### B7. `core/security/` (3)

| File | Peran | Komentar utama |
|---|---|---|
| `db_key_store.dart` | Kunci enkripsi DB (secure storage) | `:5` "Penyimpanan kunci enkripsi database lokal"; `:30` kunci 256-bit CSPRNG |
| `password_hasher.dart` | PBKDF2-HMAC-SHA256 | `:7` "Hash password dengan **PBKDF2-HMAC-SHA256 + salt unik per pengguna**"; `:21` 210.000 iterasi |
| `session.dart` | Model sesi login | `:4` "Model sesi login (deskripsi proyek Bagian 5.1)"; `:49` token 32 byte |

### B8. `core/sensors/` (4)

| File | Peran | Komentar utama |
|---|---|---|
| `auto_theme.dart` | Auto-Theme dari sensor cahaya | `:9` "Sensor 1 — *Auto-Theme* dari sensor cahaya"; `:53` `reset()` |
| `sensor_streams.dart` | Stream accelerometer & lux | `:9` "Stream sampel *user accelerometer* (tanpa gravitasi)"; `:31` stream lux |
| `shake_detector.dart` | Logika deteksi shake murni | `:19` "Detektor *Shake to Discover* — dokumen desain Bagian 4 / workflow 3.6" |
| `shake_discover.dart` | Watcher shake per rute + modal | `:39` "Pemantau *Shake to Discover*"; `:103` buku acak Wishlist |

### B9. `core/theme/` — design tokens (4)

| File | Peran | Komentar utama |
|---|---|---|
| `app_colors.dart` | Token warna indigo/slate terang+gelap | `:3` "Design token warna Storyloka — dokumen desain Bagian 1.1 (Palet Indigo/Slate)" |
| `app_dimensions.dart` | Spacing, radius, ukuran tetap | `:3` "Design token spacing, radius, elevasi, dan ukuran tetap" |
| `app_theme.dart` | `ThemeData` dari token | `:7` "Membangun [ThemeData] terang & gelap Storyloka dari design tokens" |
| `app_typography.dart` | Tipografi Inter H1–Caption | `:3` "Design token tipografi Storyloka — dokumen desain Bagian 1.2"; `:59` angka stopwatch |

### B10. `core/utils/` (4)

| File | Peran | Komentar utama |
|---|---|---|
| `book_status.dart` | Enum + label status buku | `:1` "Model status buku — konsisten di semua layar (dokumen desain Bagian 7)" |
| `currency.dart` | Konversi IDR/USD/EUR/JPY | `:1` "Konversi mata uang (F-17, SCR-04): IDR, USD, EUR, JPY" |
| `reading_stats.dart` | Ringkasan baca & streak | `:6` "Ringkasan baca untuk SCR-02 (Reading Summary) dan SCR-15 (target)" |
| `world_clock.dart` | Zona waktu + DST London | `:1` "Konversi zona waktu (F-18, SCR-04): WIB (UTC+7), WITA (UTC+8)…" |

### B11. `core/widgets/` — komponen Master Layout (11)

| File | Peran | Komentar utama |
|---|---|---|
| `book_cover.dart` | Sampul 2:3 radius 8 | `:8` "Sampul buku — dokumen desain Bagian 8: rasio 2:3, radius 8" |
| `bottom_nav_bar.dart` | Bottom nav 5 slot | `:7` "Bottom navigation 5 slot — dokumen desain Bagian 3.1 dan 8" |
| `buttons.dart` | Tombol Primary/Secondary 48 dp | `:5` "PrimaryButton & SecondaryButton — dokumen desain Bagian 8" |
| `empty_state.dart` | State kosong SCR-12 | `:8` "State kosong — dokumen desain SCR-12" |
| `error_state.dart` | State error/offline SCR-13 | `:8` "State error & offline — dokumen desain SCR-13" |
| `loading_skeleton.dart` | Shimmer SCR-11 | `:6` "State loading berbentuk shimmer — dokumen desain SCR-11" |
| `profile_avatar.dart` | Foto profil atau inisial | `:7` "Avatar profil: menampilkan foto lokal (`users.photo_path`) bila ada" |
| `screen_placeholder.dart` | Badan layar placeholder WF-01 | `:6` "Badan isi standar untuk layar placeholder WF-01" |
| `status_badge.dart` | Badge status berbentuk pil | `:8` "Badge status buku berbentuk pil — dokumen desain Bagian 8 & 7" |
| `storyloka_card.dart` | Kartu dasar Zona 2 | `:6` "Kartu dasar Storyloka — dokumen desain Bagian 8" |
| `top_bar.dart` | Zona 1, 56 dp, maks 2 aksi | `:5` "Zona 1: Top Bar 56dp, sticky, maksimum 2 ikon aksi" |

## C. `lib/features/` — layar & fitur (40 file)

| File | Peran | Komentar utama | Dokumen WF |
|---|---|---|---|
| `ai/ai_assistant_screen.dart` | Chat AI SCR-05 | `:23` "SCR-05 - AI / LLM Assistant (F-11 / WF-07)" | WF-07 |
| `auth/auth_controller.dart` | State & aksi auth | `:50` "Pengendali register / login / logout / biometrik (workflow Bagian 3.1-3.2)"; `:9` state | WF-02 |
| `auth/auth_screen.dart` | Form login/register SCR-01 | `:13` "SCR-01 — Splash, Register, Login & Biometrik (F-01…F-03)" | WF-02 |
| `auth/auth_store.dart` | Simpan token di secure storage | `:6` "Penyimpanan sesi & penanda pengguna aktif"; `:21` Keychain/Keystore | WF-02 |
| `auth/biometric_service.dart` | Pembungkus `local_auth` | `:4` "Pembungkus `local_auth` untuk verifikasi biometrik (F-03)" | WF-02 |
| `auth/session_service.dart` | Cek/buat/hapus sesi | `:6` "Layanan sesi: membuat, memeriksa, dan mengakhiri sesi login" | WF-02 |
| `auth/splash_screen.dart` | Splash SCR-01 + routing awal | `:17` "SCR-01 — Splash (F-01…F-03)" | WF-02 |
| `auth/user_repository.dart` | Tabel `users` lokal | `:35` "Akses tabel `users` untuk autentikasi lokal (deskripsi Bagian 5.1)"; `:7` galat auth | WF-02 |
| `blockchain/blockchain_card.dart` | Kartu blockchain SCR-06 | `:20` "Kartu 🛡 Blockchain / Sertifikat di SCR-06 (F-12 / WF-08)" | WF-08 |
| `blockchain/certificate_share_service.dart` | Bagikan PNG sertifikat | `:6` "Berbagi gambar sertifikat bacaan (Bagian 5.7)"; `:14` `share_plus` | WF-08 |
| `blockchain/reading_certificate.dart` | Kartu sertifikat Proof of Reading | `:10` "Kartu sertifikat 'Proof of Reading'" | WF-08 |
| `book_detail/book_ai_card.dart` | Kartu AI di SCR-06 | `:16` "Kartu ✨ AI di SCR-06 (F-11 / WF-07)" | WF-07 |
| `book_detail/book_detail_data.dart` | Provider data SCR-06 | `:16` "Seluruh data SCR-06 dalam satu async provider" | WF-05 |
| `book_detail/book_detail_screen.dart` | Detail buku SCR-06 | `:31` "SCR-06 — Detail Buku & Blockchain Proof-of-Reading" | WF-05 |
| `book_detail/completion.dart` | Dialog tandai selesai + ulasan wajib | `:19` "Menandai buku **Selesai** — workflow Bagian 3.3" | WF-05/08 |
| `explore/converter_panel.dart` | Konverter mata uang & waktu | `:16` "Konverter mata uang (F-17, SCR-04)"; `:199` "Konverter zona waktu (F-18)" | WF-05 |
| `explore/explore_screen.dart` | Layar Explore SCR-04 | `:41` "SCR-04 — Explore: Peta (LBS), Konverter & Game"; `:17` segmen game | WF-06/09 |
| `explore/peta_panel.dart` | Peta toko buku (LBS) | `:16` "Segmen **Peta (LBS)** SCR-04 — F-16 / WF-06" | WF-06 |
| `feedback/feedback_screen.dart` | Kesan & saran SCR-10 | `:16` "SCR-10 — Saran & Kesan Mata Kuliah Pemrograman Aplikasi Mobile (F-08)" | WF-04 |
| `game/game_screen.dart` | Kuis SCR-16 | `:22` "SCR-16 — Permainan Book Trivia (F-13 · WF-09)"; `:51` timer timestamp | WF-09 |
| `game/question_bank.dart` | Bank 31 soal + generator ronde | `:26` "Bank soal lokal Book Trivia (deskripsi Bagian 5.8 — soal bawaan offline)"; `:282` `buildRound` | WF-09 |
| `game/quiz_session.dart` | Mesin kuis state murni | `:6` "Mesin kuis Book Trivia — state murni tanpa UI (mudah diuji unit)" | WF-09 |
| `home/home_data.dart` | Provider data SCR-02 | `:10` "Seluruh data SCR-02 dalam satu async provider" | WF-05 |
| `home/home_screen.dart` | Beranda SCR-02 | `:24` "SCR-02 — Beranda, Ringkasan & Currently Reading (F-19, WF-05)"; `:422` pantau `/health` | WF-05 |
| `library/add_book_screen.dart` | Tambah/edit buku SCR-07 | `:21` "SCR-07 — Tambah / Edit Buku (F-10, F-20 · WF-05)" | WF-05 |
| `library/book_tile.dart` | Kartu buku grid/list | `:45` "Kartu buku grid 2 kolom SCR-03"; `:11` baris rating | WF-05 |
| `library/filter_sheet.dart` | Bottom sheet filter & sort | `:11` "Bottom sheet filter & sort SCR-08" | WF-05 |
| `library/library_data.dart` | Model filter/tab pencarian | `:32` "Filter & pencarian buku yang dipakai SCR-03 dan SCR-08"; `:21` tab | WF-05 |
| `library/library_screen.dart` | Library SCR-03 | `:19` "SCR-03 — Library: Koleksi & Wishlist (F-10, WF-05)" | WF-05 |
| `notifications/notifications_data.dart` | Riwayat SCR-14 | `:7` "Riwayat notifikasi milik pengguna aktif — SCR-14" | WF-06 |
| `notifications/notifications_screen.dart` | Pusat notifikasi SCR-14 | `:15` "SCR-14 — Pusat Notifikasi (F-14 / WF-06)" | WF-06 |
| `profile/edit_profile_screen.dart` | Edit profil SCR-17 | `:16` "SCR-17 — Edit Profil (F-07)" | WF-04 |
| `profile/photo_service.dart` | Picker foto (abstraksi) | `:8` "Pengambil foto profil dari kamera/galeri (SCR-17, F-07)" | WF-04 |
| `profile/profile_data.dart` | Provider data SCR-09 | `:12` "Seluruh data yang ditampilkan SCR-09 dalam satu async provider" | WF-04 |
| `profile/profile_screen.dart` | Profil SCR-09 | `:20` "SCR-09 — Profil, Pengaturan & Keamanan (F-02, F-03, F-07, WF-04)" | WF-04 |
| `profile/profile_stats.dart` | Statistik ringkas | `:7` "Statistik ringkas profil (SCR-09)" | WF-04 |
| `reading_session/reading_session_screen.dart` | Sesi baca SCR-15 | `:36` "SCR-15 — Sesi Membaca (Stopwatch) (F-19, WF-05)"; `:154` simpan sesi | WF-05 |
| `reading_session/session_timer.dart` | Stopwatch timestamp | `:1` "Stopwatch sesi membaca berbasis **timestamp** (F-19, SCR-15)" | WF-05 |
| `search/search_data.dart` | State pencarian online | `:10` "Kata kunci pencarian online (SCR-08 tab 'Cari Online')"; `:32` simpan hasil | WF-05 |
| `search/search_screen.dart` | Pencarian SCR-08 | `:18` "SCR-08 — Pencarian & Filter (F-10, WF-05)" | WF-05 |

## D. `lib/main.dart` — titik masuk (1 file, tanpa komentar)

`void main()` → `WidgetsFlutterBinding.ensureInitialized()` → `runApp(ProviderScope(child: StorylokaApp()))`.

## E. `test/` — 21 file uji (semua berbahasa Indonesia)

| File | Peran | Kasus |
|---|---|---|
| `auth_flow_test.dart` | Alur auth end-to-end (provider disuntikkan) | TC-01…TC-08 |
| `session_test.dart` | Sesi valid/kedaluwarsa/auto-login | TC-05, TC-06 |
| `password_hasher_test.dart` | PBKDF2-HMAC-SHA256, 210.000 iterasi, constant-time | param KDF (K-13) |
| `widget_test.dart` | Bottom nav 5 slot, tab, dialog Logout | TC-09 |
| `edit_profile_test.dart` | Ganti foto → tampil SCR-17/SCR-09/Beranda | TC-10 |
| `feedback_flow_test.dart` | Simpan kesan → antrean → terkirim | TC-11 |
| `profile_test.dart` | Update profil, email ganda, ganti password, tema | WF-04 |
| `db_test.dart` | Skema, migrasi, LWW/insert-if-absent | WF-03 |
| `book_repository_test.dart` | CRUD buku, dirty, soft delete, LWW | WF-03 |
| `sync_test.dart` | Offline→antrean→online, kick backoff | TC-29 |
| `library_flow_test.dart` | Tambah buku, filter, stopwatch, sesi→selesai | TC-12…TC-16 |
| `converter_test.dart` | Kurs + zona waktu (DST London) | TC-17, TC-18 |
| `shake_test.dart` | Modal shake + tidak salah picu | TC-19, TC-20 |
| `auto_theme_test.dart` | Histeresis lux 15/40, mode manual | TC-21 |
| `lbs_test.dart` | Izin ditolak, GPS mati, kartu ajakan | TC-22 |
| `notification_test.dart` | Setelan→jadwal→fires→ketuk→riwayat | TC-23 |
| `ai_test.dart` | Ringkasan+cache, offline/batal→Coba Lagi | TC-24, TC-25 |
| `blockchain_test.dart` | Blok+validasi Valid / tidak valid (TC-27) | TC-26, TC-27 |
| `game_test.dart` | Ronde 10 soal → skor 1000/koin 100 | TC-28 |
| `theme_test.dart` | Design tokens (warna/typography/dimensi) | desain Bagian 1 |
| `performance_test.dart` | Metrik performa (seed 200 buku, PBKDF2, splash) | WF-10 |

## F. `backend/src/` — 21 file JavaScript

### F1. Kerangka (2)

| File | Peran | Komentar utama |
|---|---|---|
| `app.js` | Instance Express + pemasangan rute | `:12` daftar lengkap endpoint per WF (health, auth, sync, feedback, rates, ai) |
| `server.js` | Proses listen (terpisah dari `app.js`) | `:6` "`host 0.0.0.0` agar bisa diakses dari HP fisik via IP komputer" |

### F2. Config & middleware (3)

| File | Peran | Komentar utama |
|---|---|---|
| `config/env.js` | Pembaca environment | `:3` "Nilai rahasia (API key, dsb.) hanya dibaca dari environment / `.env` dan TIDAK PERNAH dicetak ke log atau dikirim ke klien" |
| `middleware/auth.js` | `requireAuth` Bearer token | `:3` "semua endpoint selain register/login wajib menyertakan `Authorization: Bearer <token sesi>`" |
| `middleware/error.handler.js` | 404 JSON + error global | `:11` "Penangan error global… Pesan error internal tidak dibocorkan ke klien di produksi" |

### F3. Controllers (6) — kontrak HTTP

| File | Peran | Komentar utama |
|---|---|---|
| `controllers/ai.controller.js` | `POST /ai/{chat,summarize,recommend}` | `:8` pemetaan galat 429/504/503/502; `:28/:48/:70` kontrak per endpoint |
| `controllers/auth.controller.js` | register/login/logout | `:17` "register balas 201 { token, expiresAt, user }"; `:51` pesan umum; `:85` logout hapus token |
| `controllers/feedback.controller.js` | POST/GET `/feedback` | `:15` "minimal satu kolom terisi; konflik *last-write-wins* per pengguna" |
| `controllers/health.controller.js` | `GET /health` | `:3` "dipakai WF-01 untuk memastikan aplikasi Flutter tersambung ke backend" |
| `controllers/rates.controller.js` | `GET /rates` | `:3` "kurs… `rates` = IDR per 1 unit (sama dengan kolom `rate_cache` klien)" |
| `controllers/sync.controller.js` | `POST /sync` | `:17` kontrak `{ since, books[], … }` → snapshot penuh, LWW |

### F4. Services (4) — logika & penyimpanan

| File | Peran | Komentar utama |
|---|---|---|
| `services/ai.service.js` | Proxy Gemini + `AI_MOCK`/`AI_DISABLED` | `:3` ketentuan proxy (key di server, prompt topik buku, K-18); `:15` prompt sistem |
| `services/rate.store.js` | Cache kurs + provider publik | `:7` "Provider publik tanpa API key (keputusan 18: proyek $0)… kegagalan jatuh ke cache terakhir, lalu nilai statis" |
| `services/sync.store.js` | Data sinkronisasi per pengguna | `:5` aturan konflik LWW / insert-if-absent; `:130` snapshot penuh |
| `services/user.store.js` | Pengguna & sesi server | `:6` "Server menyimpan **hash miliknya sendiri**… PBKDF2-HMAC-SHA256 identik dengan skema klien"; `:126` sesi 7 hari |

### F5. Routes (6) — pemasangan prefix + `requireAuth`

| File | Peran | Komentar utama |
|---|---|---|
| `routes/ai.route.js` | Prefix `/ai` (WF-07) | `:12-13` semua endpoint butuh token; API key tetap di server |
| `routes/auth.route.js` | Prefix `/auth` (WF-02) | `:8`, `:11` logout butuh token sesi |
| `routes/feedback.route.js` | Prefix `/feedback` (WF-04) | `:8` |
| `routes/health.route.js` | Prefix `/health` (WF-01) | `:7` |
| `routes/rates.route.js` | Prefix `/rates` (WF-05) | `:8-9` butuh token sesi |
| `routes/sync.route.js` | Prefix `/sync` (WF-03) | `:8-9` butuh token sesi (Bagian 5.2) |

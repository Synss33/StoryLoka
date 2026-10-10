# Progres Pengerjaan Storyloka

> **File ini HANYA catatan kemajuan.** Aturan fitur/teknis tetap mengikuti
> tiga dokumen utama: `deskripsi_proyek.md` → `referensi_desain_ui_ux.md` →
> `workflow_proyek.md`. Bila ada selisih, dokumen utama yang berlaku.
>
> **Aturan pembaruan:** centang/ubah file ini **setiap akhir sesi kerja**
> atau setiap modul selesai, lalu commit bersama hasil kerja.

**Terakhir diperbarui:** 2026-10-10 · **Branch aktif:** `feature/wf-02-auth` (siap merge ke `develop`)

## Status Ringkas

| Modul | Judul | Status | Target minggu |
|---|---|---|---|
| WF-01 | Setup & Fondasi | ✅ **Selesai** | 1 |
| WF-02 | Auth, Session, Biometrik, Logout | ✅ **Selesai** (sisa verifikasi HP — lihat bawah) | 2 |
| WF-03 | Data Lokal & Online | ⬜ Belum | 2 |
| WF-04 | Navigasi, Profil, Kesan | ⬜ Belum | 2 |
| WF-05 | Library, Tracker, Pencarian, Konverter | ⬜ Belum | 2–3 |
| WF-06 | Sensor, LBS, Notifikasi | ⬜ Belum | 3 |
| WF-07 | AI / LLM (via backend) | ⬜ Belum | 4 |
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

### Catatan teknis (rincian di `docs/keputusan.md` 13–17)
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

## ⬜ WF-03 Data Lokal & Online (F-04, F-05 · semua layar)

- [ ] Model Dart per tabel + repository (CRUD offline via SQLite, penanda `dirty`).
- [ ] REST client umum (Bearer token, error handling, timeout).
- [ ] `POST /sync` dua arah (buku, sesi, catatan, blok, setting) — konflik **last-write-wins** `updated_at`.
- [ ] Antrian sinkron otomatis saat kembali online; tandai `synced`.
- [ ] Backend: `POST /sync` (atau minimal tulang punggungnya).
- [ ] Test: TC-29 (offline lalu sinkron).

## ⬜ WF-04 Navigasi, Profil, Kesan (F-06–F-08 · SCR-09, 10, 17)

- [ ] SCR-09 Profil: data pengguna, statistik ringkas, pengaturan tema (auto/terang/gelap) + persistensi ke tabel `settings`.
- [ ] SCR-17 Edit Profil: ubah nama/email/foto (kamera/galeri) → simpan.
- [ ] Foto profil: simpan lokal (path), tampil di Profil & Beranda.
- [ ] SCR-10 Kesan & Saran: form untuk **mata kuliah Pemrograman Aplikasi Mobile** (bukan penilaian aplikasi) → simpan lokal + `POST /feedback`.
- [ ] Backend: `POST /feedback`, `GET /feedback`.
- [ ] Screenshot Light & Dark SCR-09, 10, 17 (+ rekap screenshot WF-01).
- [ ] Test: TC-09, TC-10, TC-11.

## ⬜ WF-05 Library, Tracker, Pencarian, Konverter (F-10, F-17–F-19 · SCR-02, 03, 06, 07, 08, 15, 04)

- [ ] SCR-03 Koleksi & Wishlist: daftar buku, filter chip status, FAB tambah.
- [ ] SCR-07 Tambah/Edit Buku: validasi (judul wajib, halaman ≥ 1), sampul (galeri/kamera/manual).
- [ ] SCR-06 Detail Buku: progres, total jam, streak, ulasan & rating wajib saat selesai → picu blockchain (WF-08).
- [ ] SCR-15 Sesi Baca: **stopwatch dari timestamp** (akurat di latar belakang), input halaman terakhir, target bulanan.
- [ ] SCR-08 Pencarian: lokal (judul/penulis/ISBN) + online (Google Books/Open Library) → pilih → form terisi.
- [ ] Filter (genre, status, rating, tahun) & sort (terbaru, judul, rating).
- [ ] SCR-02 Beranda: ringkasan (buku sedang dibaca, target, streak) dari data nyata.
- [ ] Konverter: kurs IDR/USD/EUR/JPY (`GET /rates`, cache offline) + zona waktu WIB/WITA/WIT/London (DST).
- [ ] Test: TC-12…TC-18.

## ⬜ WF-06 Sensor, LBS, Notifikasi (F-14–F-16 · SCR-02, 04, 09, 14)

- [ ] Shake (accelerometer): pilih buku acak dari Wishlist + haptic; threshold anti-salah-picu.
- [ ] Auto-theme sensor cahaya (Android) → mode `auto`; fallback tema sistem di iOS.
- [ ] SCR-04 Peta: OpenStreetMap (tanpa API key) lokasi perpustakaan/rute; izin lokasi + kartu ajakan bila ditolak.
- [ ] SCR-14 Notifikasi: pengingat baca terjadwal (izin Android 13+), riwayat tercatat.
- [ ] Test: TC-19…TC-23.

## ⬜ WF-07 AI / LLM via Backend (F-11 · SCR-05, 06)

- [ ] Backend proxy: `POST /ai/chat`, `POST /ai/summarize`, `POST /ai/recommend` (Gemini, **API key hanya di `.env` server**).
- [ ] SCR-05 AI Assistant: chat + konteks buku; loading, timeout, pesan kuota/offline.
- [ ] Ringkasan buku di SCR-06; hasil di-cache lokal; label **"Dihasilkan AI"**.
- [ ] Test: TC-24, TC-25.

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

# Keputusan Teknis (Storyloka)

Catatan keputusan desain/implementasi selama pengerjaan. Setiap keputusan
mencantumkan alasan singkat dan referensi dokumen rujukan.

Prioritas jika konflik: **Ketentuan Dosen > deskripsi proyek > desain > workflow**.

## WF-01 Setup & Fondasi

| # | Keputusan | Alasan |
|---|---|---|
| 1 | **Tanpa Firebase** — REST API sendiri (Node.js + Express), sesuai ketentuan dosen di `docs/deskripsi_proyek.md`. | Ketentuan dosen; API key LLM hanya boleh berada di server. |
| 2 | **Backend WF-01 hanya menyediakan `GET /health`** (backend "kosong" tetapi tersambung). Endpoint `books`, `sync`, `feedback`, `ai/*`, `rates` menyusul di WF-03…WF-07 sesuai `docs/deskripsi_proyek.md` Bagian 5.2 (`auth` menyusul di WF-02 — lihat keputusan 14). | Definition of Done WF-01 hanya meminta backend kosong terhubung. |
| 3 | **Express 5 + ESM** (`"type": "module"`), mode dev `node --watch`, test memakai `node --test` bawaan Node (tanpa Jest/supertest). | Stack minimal sesuai `docs/workflow_proyek.md` Bagian 4.2 (Node.js/Express); mengurangi dependensi. |
| 4 | **Base URL API lewat `--dart-define=API_BASE_URL=…`**, nilai bawaan `http://10.0.2.2:3000` (loopback emulator Android). HP fisik: `http://<ip-komputer>:3000`. | Tidak ada URL hard-coded di kode; mudah berganti lingkungan. |
| 5 | **`android:usesCleartextTraffic="true"` sementara** agar backend lokal `http://` bisa diakses saat pengembangan; sebelum rilis dihapus dan memakai HTTPS. | `docs/workflow_proyek.md` Bagian 4.3 mewajibkan HTTPS. |
| 6 | **`.env` backend tidak dikomit**; hanya `.env.example` yang masuk repo. API key (mis. `GEMINI_API_KEY`) hanya dibaca di server. | Bagian 4.3: dilarang menyimpan API key di repo/aplikasi. |
| 7 | **SQLCipher hanya tersedia di Android/iOS/macOS.** Unit test di host Windows memakai `sqflite_common_ffi` (SQLite polos) dengan pabrik disuntik; kebuka-terenkripsi diverifikasi di perangkat fisik. | `sqflite_sqlcipher` 3.4.1 tidak menyediakan build Windows; skema tetap diuji lewat host. |
| 8 | **Kunci DB = acak 256-bit (`Random.secure`), disimpan di secure storage** dengan alias `storyloka.db.key`; **bukan** diturunkan dari password pengguna. | Agar login biometrik tetap bisa membuka database (deskripsi Bagian 5.1); password hanya untuk hash auth. |
| 9 | **State management Riverpod 3** (`Notifier`/`NotifierProvider`), navigasi **go_router 18** dengan `StatefulShellRoute.indexedStack` (4 cabang) + rute fokus di luar shell — bottom nav otomatis sembunyi di SCR-05…08 dan 15…17. | Mengikuti `docs/workflow_proyek.md` Bagian 4.2 dan `docs/referensi_desain_ui_ux.md` Bagian 3.3. |
| 10 | **Font Inter di-bundle lokal** (`assets/fonts/`, 4 weight) alih-alih paket `google_fonts`. | Deterministik, mendukung mode offline, lisensi (OFL) ikut di-bundle. |
| 11 | **Mode tema**: enum `StorylokaThemeMode { auto, terang, gelap }` di Riverpod; "auto" mengikuti tema sistem sampai sensor cahaya (WF-06); persistensi ke tabel `settings` menyusul WF-04. **Stopwatch sesi membaca dihitung dari timestamp** (bukan penghitung per detik). | Desain Bagian 1.5; stopwatch akurat saat aplikasi di latar belakang (ketentuan dosen, deskripsi Bagian 5.4). |
| 12 | **Komponen Android SDK yang dipakai**: `platforms;android-35` & `36`, `build-tools;36.0.0`, `ndk;28.2.13676358`, `cmake;3.22.1` (dua terakhir dipasang manual saat build pertama gagal karena auto-install sdkmanager dari Gradle tidak berjalan). `flutter build apk --debug` terverifikasi. | Reprodukabilitas build di mesin anggota lain. |

## WF-02 Auth, Session, Biometrik, Logout

| # | Keputusan | Alasan |
|---|---|---|
| 13 | **Password di-hash dengan PBKDF2-HMAC-SHA256** (salt acak 16 byte, 210.000 iterasi, output 32 byte) — bukan Argon2id. | Deskripsi Bagian 5.1 mengizinkan keduanya; implementasi `cryptography` murni Dart → logika hash dapat diuji di host Windows tanpa plugin native. Parameter KDF dicatat di kolom `kdf_params` agar bisa direproduksi. |
| 14 | **Server menyimpan hash miliknya sendiri** (hash ulang PBKDF2 `node:crypto` + salt acak) pada file JSON di `backend/data/` (di-gitignore, bukan basis data eksternal); sesi = token acak 32 byte berlaku 7 hari. | Sesuai Bagian 5.1 "Server juga menyimpan hash miliknya sendiri" dan Bagian 5.2 (Bearer token untuk endpoint selain register/login); skema JSON file cukup untuk cakupan tugas tanpa dependensi DB server. |
| 15 | **`MainActivity` mewarisi `FlutterFragmentActivity`** (bukan `FlutterActivity`). | Syarat paket `local_auth` di Android agar dialog biometrik tampil (dokumentasi plugin). |
| 16 | **Test widget memakai `databaseFactoryFfiNoIsolate` + `tester.runAsync` untuk seed.** | Operasi `sqflite_common_ffi` berbasis isolate **tidak pernah selesai** di zona fake-async `testWidgets` (pumpAndSettle timeout); varian no-isolate selesai via microtask sehingga pump memprosesnya. |
| 17 | **Klien mengirim `POST /auth/register`, `/auth/login`, `/auth/logout` secara best-effort** (gagal/ offline diabaikan, data lokal tetap sumber utama). | Alur workflow §3.2 "simpan user lokal (+ POST jika online)"; WF-03 akan memakai kembali jalur ini saat sinkronisasi. |
| 18 | **Proyek dirancang tanpa biaya wajib ($0).** Semua stack open source; pencarian buku (Google Books/Open Library) & peta (OpenStreetMap) tanpa API key/billing; backend berjalan lokal. Satu-satunya potensi biaya: **Gemini API (WF-07)** memakai **tier gratis Google AI Studio** (kuota per menit/hari) — aplikasi tetap berfungsi tanpa key (cache + pesan batas kuota). Opsional & belum perlu: hosting backend online (free tier) hanya untuk demo lintas jaringan; Apple Developer $99/thn hanya bila wajib build iOS. | `deskripsi_proyek.md` Bagian 5.2 (peta "Gratis, tanpa billing"); `workflow_proyek.md` Bagian 5 (mitigasi "Kuota/limit Gemini"); hemat untuk tugas akhir dan mendukung mode offline-first. |

## WF-03 Data Lokal & Online

| # | Keputusan | Alasan |
|---|---|---|
| 19 | **Model Dart diletakkan di `lib/core/models/` dan repository di `lib/core/db/`** (bersama `settings_repository`). Model dibuat untuk 7 tabel data inti (books, reading_sessions, notes_quotes, reviews, blocks, feedback, settings); tabel lokal-murni (`notifications`, `rate_cache`, `game_scores`) menyusul bersama fiturnya (WF-06/WF-09), `users` sudah punya `UserRecord` (WF-02). | Ikuti struktur folder yang sudah berjalan (workflow Bagian 4.2 bersifat disarankan); tidak membuat model yang belum dikonsumsi siapa pun. |
| 20 | **Skema SQLite naik ke v2**: menambah `settings.updated_at` via `ALTER TABLE` di `onUpgrade`. | Ketentuan LWW *last-write-wins berdasarkan `updated_at`* (Bagian 5.2) berlaku juga untuk pengaturan; migrasi wajib menaikkan versi (aturan di `schema.dart`). |
| 21 | **Kontrak `POST /sync`**: permintaan = baris `dirty` (buku/feedback) + seluruh baris append-only (sesi/catatan/ulasan/blok) + settings; balasan = **snapshot penuh** per pengguna + `serverTime`. ID lokal (autoincrement) dipertahankan — asumsi **satu perangkat utama per pengguna**. | Skala tugas akhir kecil → snapshot penuh membuat balasan idempoten dan sederhana; konflik tetap diselesaikan LWW di klien maupun server. Bila kelak multi-perangkat, ganti ID lokal dengan UUID (catatan di laporan). |
| 22 | **Deteksi "kembali online" tanpa paket connectivity_plus**: `kick()` dipanggil saat splash masuk Beranda (dan nanti setelah aksi tulis); bila gagal, antrean dijaga oleh **backoff 5 → 15 → 60 → 300 detik** sampai server menerima data. | Hemat dependensi & izin; alur §3.7 "tetap di antrean, coba lagi saat koneksi kembali" terpenuhi tanpa izin jaringan tambahan; periode server mati >5 menit tergolong jarang saat pengembangan. |

## WF-04 Navigasi, Profil, Kesan

| # | Keputusan | Alasan |
|---|---|---|
| 23 | **`image_picker` dibungkus abstraksi `PhotoPicker` + `ProfilePhotoStore`.** Store menyalin hasil pilih ke direktori dokumen aplikasi (`profile_photo.<ext>`) agar path stabil; test TC-10 menyuntikkan picker/store palsu (tanpa kamera/IO nyata). | Paket sesuai tabel paket deskripsi Bagian 5.4; file cache picker bisa dibersihkan sistem; abstraksi menghindari panggilan platform & IO async di zona fake-async `testWidgets`. |
| 24 | **Skema naik v3**: menambah `settings.streak_notify` (toggle "Notifikasi target & streak" di SCR-09) via `ALTER TABLE`; pembaruan juga dicatat di tabel model data `deskripsi_proyek.md`. | Label toggle ada di desain SCR-09 tetapi kolomnya belum ada; penjadwalan sistem tetap di WF-06 (workflow §4.6). |
| 25 | **Feedback = satu baris per pengguna.** Klien `upsert` berdasarkan `user_id` (bukan id autoincrement); server `saveFeedback` memakai key = `user_id` di `sync.store`. | Desain SCR-10 hanya menyimpan "isi terakhir" dan mengeditnya kembali; aturan LWW per pengguna, tanpa tumpukan baris lama. |
| 26 | **`[Level Pembaca]` dihitung dari jumlah buku selesai**: Pemula (<10), Rutin (10–49), Kutu Buku (≥50) — disimpan tidak perlu (selalu diturunkan dari statistik). | Desain menampilkan label tanpa aturan hitung; turunan lokal selalu konsisten dengan statistik profil. |
| 27 | **`POST /feedback` best-effort + `GET /feedback` hanya bila data lokal kosong** (lokal-first). Setelah POST sukses baris ditandai `synced=1`; gagal → tetap antrean `/sync`. | Deskripsi Bagian 5.13 "disimpan lokal dan dikirim"; tarik server hanya saat perangkat belum punya isi agar coretan belum terkirim tidak tertimpa. |

## WF-05 Library, Tracker, Pencarian, Konverter

| # | Keputusan | Alasan |
|---|---|---|
| 28 | **Kurs mata uang dari `GET /rates` backend** (penyedia open.er-api.com, TTL 6 jam, fallback bawaan) dengan cache SQLite tabel `rate_cache`; pencarian buku tetap Google Books/Open Library tanpa key. | Keputusan 18 (proyek $0) + deskripsi Bagian 5.12 "cache untuk offline"; backend menjembatani agar tidak ada API key di aplikasi dan pemakaian kuota terkendali. |
| 29 | **Semua `showModalBottomSheet` memakai `useRootNavigator: true`.** | Bottom sheet yang dibuka di dalam Navigator cabang `StatefulShellRoute` berada **di bawah** bottom nav (Zona 4, `Scaffold.bottomNavigationBar`) → tombol sheet (mis. "Terapkan") bisa terkena tap nav dan berpindah tab (terdeteksi saat TC-14). |
| 30 | **Stopwatch sesi memakai `SessionTimer` berbasis timestamp** (`start_ts` + akumulasi jeda), tampilan diperbarui `Timer.periodic` 1 dtk; durasi disimpan dari selisih waktu nyata. | Ketentuan dosen: akurat ±1 dtk meski aplikasi pindah ke latar belakang (TC-15); penghitung per detik akan meleset karena timer berhenti saat background. |
| 31 | **Carousel "My Collection" di SCR-02 memakai tinggi 300 dp** (kartu `BookCard` lebar 110 dp). | Cover 2:3 (165 dp) + judul 2 baris + penulis + rating/badge ≈ 261-290 dp; tinggi 240 dp menyebabkan overflow 49 dp (terdeteksi widget test TC-16). |

## WF-06 Sensor, LBS, Notifikasi

| # | Keputusan | Alasan |
|---|---|---|
| 32 | **`NotificationService` berupa abstraksi dengan implementasi Android/iOS (`flutter_local_notifications`) dan fake untuk test**; payload notifikasi berformat `type|userId|rute` agar callback ketuk bisa mencatat riwayat + navigasi. | Ketentuan dosen melarang Firebase — notifikasi sistem memakai plugin lokal; seam abstraksi membuat TC-23 bisa menyimulasikan OS (jadwal → fires → diketuk) sepenuhnya di host. |
| 33 | **Peta SCR-04 memakai `flutter_map` + OpenStreetMap tiles + Overpass API tanpa API key**; izin lokasi runtime (kartu ajakan bila ditolak; titik perpustakaan statis bila izin tidak diberikan). | Keputusan 18 (proyek $0) + deskripsi Bagian 5.9 "gratis, tanpa billing"; Overpass tidak memerlukan key. |
| 34 | **Android: izin `POST_NOTIFICATIONS` (API 33+) & lokasi runtime + `coreLibraryDesugaring` `desugar_jdk_libs` 2.1.4** (wajib `flutter_local_notifications` memakai `java.time`). Shake: ambang magnitudo 12 m/s², jendela 600 ms, debounce 1500 ms. Auto-theme: lux < 15 selama ≥ 2 dtk → gelap; > 40 → terang (zona 15–40 = histeresis anti-ambang-awang); hanya Android — iOS mengikuti tema sistem. | Syarat teknis plugin & sensor (workflow §3.6/3.8); ambang/histeresis mencegah shake salah-picu dan tema berkedip saat lux berada di batas. |
| 35 | **`NotificationCoordinator` membaca provider secara sinkron (`AsyncValue.value`), bukan `await provider.future`.** Pengujian membuktikan `await provider.future` dari zona nyata `tester.runAsync` menggantung pada Riverpod 3.4 + flutter_test bila future provider tersebut telah diselesaikan di zona fake pump (satu-satunya pola yang konsisten; `.timeout` menyembunyikan gejalanya). TC-23 menulis setelan via `SettingsRepository(db)` langsung (tanpa provider) dan SCR-14 menanam riwayat sebelum boot. | Test TC-23/SCR-14 lulus 3× berturut-turut tanpa hack timeout di kode produksi; provider repo/tema sudah terisi sejak splash sehingga bacaan sinkron cukup dan lebih sederhana. |

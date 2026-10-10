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

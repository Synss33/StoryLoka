# Tech Stack Storyloka — Penjelasan untuk Laporan (Bagian Implementasi)

> Sumber: `docs/deskripsi_proyek.md` Bagian 3, `pubspec.yaml`, `backend/package.json`,
> dan `docs/keputusan.md` (nomor keputusan dicantumkan sebagai **K-xx**).
> Dipakai untuk laporan Bab Implementasi / Landasan Teori bagian teknologi.

## 1. Klien (Aplikasi Mobile — Flutter/Dart)

| Lapisan | Teknologi (versi di proyek) | Fungsi & alasan (K-xx) |
|---|---|---|
| Framework | **Flutter (Dart SDK ^3.13.5)** | Satu basis kode Android & iOS (deskripsi Bagian 3). |
| State management | **flutter_riverpod 3.4.3** (`Notifier`/`NotifierProvider`) | Konsisten di seluruh aplikasi; provider menjadi seam test (K-9). |
| Navigasi | **go_router 18.0.2** dengan `StatefulShellRoute.indexedStack` | 4 cabang shell = bottom nav 5 slot (Logout di dialog); rute di luar shell = layar fokus tanpa bottom nav (K-9, desain Bagian 3.3). |
| Database lokal | **sqflite_sqlcipher 3.4.1** (SQLite + AES-256) | DB terenkripsi sesuai ketentuan dosen (F-04); **bukan** Hive/SharedPreferences untuk data inti. Kunci DB = acak 256-bit di secure storage, bukan diturunkan dari password (K-8). |
| Database di host test | **sqflite_common_ffi 2.4.3** (`databaseFactoryFfiNoIsolate`) | SQLCipher hanya tersedia Android/iOS/macOS; skema tetap diuji di Windows (K-7, K-16). |
| Penyimpanan aman | **flutter_secure_storage 11.2.0** | Token sesi + kunci DB (Keychain/Keystore) — data sensitif tidak pernah di SharedPreferences. |
| Hash password | **cryptography 2.9.0** → PBKDF2-HMAC-SHA256, salt 16 B, **210.000 iterasi**, output 32 B | Murni Dart → bisa diuji di host; bukan Argon2id agar tanpa plugin native (K-13); param KDF disimpan di kolom `kdf_params`. |
| SHA-256 (hash chain) | **crypto 3.0.7** (`sha256.convert(...)`) | Sinkron, cocok untuk perhitungan blok blockchain; `cryptography` hanya async (K-42, deskripsi Bagian 3). |
| HTTP | **http 1.6.0** | Klien REST sederhana; base URL dari `--dart-define=API_BASE_URL` (K-4), timeout 8 detik. |
| Biometrik | **local_auth 3.0.2** | Fingerprint/Face ID; `MainActivity` = `FlutterFragmentActivity` (K-15). |
| Foto profil/cover | **image_picker 1.2.4** | Dibungkus abstraksi `PhotoPicker` + `ProfilePhotoStore` (K-23). |
| Sensor gerak | **sensors_plus 7.1.1** | Accelerometer untuk fitur shake (F-15). |
| Sensor cahaya | **light_sensor 3.0.2 (di-vendor `packages/light_sensor`)** | Auto-theme Android; di-vendor karena `jcenter()` sudah dihapus di Gradle 9 (K-40). |
| Notifikasi lokal | **flutter_local_notifications 22.3.2** + **timezone 0.11.2** + **flutter_timezone 5.1.1** | Pengingat terjadwal lokal tanpa Firebase (K-32); `coreLibraryDesugaring` wajib untuk `java.time` (K-34). |
| Peta / LBS | **flutter_map 8.3.2** + **geolocator 14.1.1** + **latlong2 0.10.1** | OpenStreetMap + Overpass API tanpa API key/billing (K-33, K-18). |
| Bagikan sertifikat | **share_plus 13.3.1** | PNG sertifikat dari `RepaintBoundary.toImage` (K-44). |
| Launcher URL | **url_launcher 6.3.3** | Buka Pengaturan/tautan eksternal. |
| Font | **Inter (di-bundle `assets/fonts/`, 4 weight)** | Deterministik & offline — bukan paket `google_fonts` (K-10). |
| Barcode (opsional) | **mobile_scanner 7.4.2** *(aktif — F-20 scan ISBN, K-58)* | Pindai barcode ISBN di SCR-07 lewat abstraksi `IsbnScanner`. |

### Perangkat & build
- **Android SDK**: `platforms;android-35 & 36`, `build-tools;36.0.0`, `ndk;28.2.13676358`, `cmake;3.22.1` (K-12).
- **Rilis ke HP**: `flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=http://<ip-pc>:3000` → APK 35,6 MB (K-41).
- **Cleartext HTTP** hanya sementara selama pengembangan (`usesCleartextTraffic="true"`), rilis wajib HTTPS (K-5).

## 2. Backend (REST API — Node.js)

| Lapisan | Teknologi | Fungsi & alasan (K-xx) |
|---|---|---|
| Runtime | **Node.js ≥ 20 (ESM `"type": "module"`)** | Natif `node --test`, tanpa transpiler (K-3). |
| Framework | **Express 5.1.0** | REST minimal sesuai workflow Bagian 4.2; **tanpa Firebase** (K-1, ketentuan dosen). |
| Middleware | **cors 2.8.5**, **dotenv 17.2.3** | CORS untuk klien Flutter; `.env` (API key) tidak dikomit (K-6). |
| Penyimpanan | **File JSON** (`backend/data/*.json`, di-gitignore) | `users.json` (hash PBKDF2 `node:crypto` + sesi token) dan `sync.json` (snapshot sinkron) — cukup untuk skala tugas akhir tanpa DB eksternal (K-14, K-21). |
| LLM | **Gemini API via proxy** (`GEMINI_API_KEY` di `.env`, model `gemini-2.5-flash`, timeout 20 dtk) | API key **hanya di server**; mode `AI_MOCK=1` untuk test, `AI_DISABLED` 503 tanpa key (K-36). |
| Kurs | **open.er-api.com** (`/v6/latest/IDR`), TTL cache 6 jam | Tanpa API key, proyek $0 (K-18, K-28); `RATES_OFFLINE=1` untuk test. |
| Test | **`node --test` bawaan Node** | Tanpa Jest/supertest (K-3). |

## 3. API Eksternal yang Dipanggil Klien (tanpa key)

| Layanan | Endpoint | Dipakai oleh |
|---|---|---|
| Google Books | `https://www.googleapis.com/books/v1/volumes` | Pencarian online SCR-08 (`book_search_service.dart`) |
| Open Library | `https://openlibrary.org/search.json` (+ `covers.openlibrary.org`) | Pencarian cadangan + cover (`book_search_service.dart`) |
| Overpass API | `https://overpass-api.de/api/interpreter` | Titik perpustakaan/toko buku SCR-04 (`book_place_service.dart`) |
| OpenStreetMap tiles | `https://tile.openstreetmap.org/...` | Peta `flutter_map` SCR-04 |

> Kurs & AI **tidak** dipanggil langsung dari klien — selalu lewat backend
> (`GET /rates`, `POST /ai/*`) agar API key/kuota terkendali (K-28, K-36).

## 4. Pengujian

| Tingkat | Alat | Cakupan |
|---|---|---|
| Unit + widget (Flutter) | **flutter_test** (88 test, 20 file `test/*_test.dart`) | TC-01…TC-29 + unit repository/model; DB disuntik `sqflite_common_ffi`, biometrik/share/picker memakai fake seam (K-16). |
| Performa | `test/performance_test.dart` (`Stopwatch`, keluaran `[perf]`) | PBKDF2, 200 buku, buildRound, bootstrap (K-50). |
| Backend | **`npm test`** = `node --test` (26 test) | auth/sync/feedback/rates/ai (AI & rates mode mock/offline). |
| Analisis statis | `flutter analyze` / `dart analyze lib test` | Wajib bersih sebelum merge (DoD Bagian 5). |

## 5. Prinsip keamanan yang menembus seluruh stack

- **Tanpa Firebase** (ketentuan dosen); **tanpa API key di klien** (K-1, K-6, K-36).
- Password hanya tersimpan sebagai **hash + salt + param KDF** (lokal & server).
- **DB terenkripsi** (SQLCipher) dengan kunci acak terpisah dari password (K-8) — login biometrik tetap bisa membuka DB.
- Token sesi: acak 32 byte, berlaku 7 hari, di secure storage; semua endpoint (kecuali register/login) memerlukan **Bearer token**.
- **Offline-first**: sumber utama = SQLite lokal; jaringan hanya sinkronisasi best-effort (K-17, K-22).

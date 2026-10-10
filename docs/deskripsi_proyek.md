# Deskripsi Proyek: Storyloka

> **📌 DOKUMEN RUJUKAN WAJIB (baca bersama file ini)**
> | Kebutuhan | File | Isi |
> |---|---|---|
> | Tampilan, layout, wireframe, komponen UI | [`referensi_desain_ui_ux.md`](./referensi_desain_ui_ux.md) | Design tokens, Master Layout, navigasi, spesifikasi layar SCR-01…SCR-17 |
> | Urutan kerja, alur sistem, standar kode, pengujian | [`workflow_proyek.md`](./workflow_proyek.md) | Roadmap, modul WF-01…WF-11, alur sistem, Definition of Done, test case |
> | Prototipe visual interaktif (5 layar awal) | [`prototipe_ui_storyloka.html`](./prototipe_ui_storyloka.html) | Gaya visual dasar dari sketsa/Figma. **Bukan acuan final**, lihat catatan di dokumen desain |
>
> **Aturan:** setiap fitur (F-xx) di dokumen ini WAJIB diimplementasikan mengikuti layar (SCR-xx) pada dokumen desain dan dikerjakan mengikuti modul (WF-xx) pada dokumen workflow.
> **Prioritas jika konflik:** Ketentuan Dosen (Bagian 1) > dokumen ini > dokumen desain > dokumen workflow.

| | |
|---|---|
| **Nama Aplikasi** | Storyloka |
| **Tagline** | Temukan, Simpan, & Lacak Bacaanmu |
| **Kategori** | Personal Book Library & Reading Tracker |
| **Mata Kuliah** | Pemrograman Aplikasi Mobile (PAM) |
| **Platform** | Android & iOS (multiplatform) |
| **Kelompok** | 1–3 orang (isi di Lampiran A) |

---

## 1. Ketentuan Tugas Akhir dari Dosen (Sumber Kebenaran)

**Teknis & fitur**
- Fitur AI dan LLM sesuai tema; mini game sederhana terkait tema.
- Fasilitas pencarian dan pemilihan; notifikasi berbasis mobile sesuai tema.
- Blockchain sederhana.
- Login dengan enkripsi (**tidak menggunakan Firebase**) dan session; login biometrik.
- Database/penyimpanan **lokal dan online** (SQLite/Hive/dll).
- Web service/API (boleh sampai IoT, game, multiplatform Android & iOS) dan fasilitas **LBS** terkait tema.
- **Bottom navigation:** menu profil (ada gambar), menu saran & kesan mata kuliah PAM, menu logout.
- Menu tambahan terpadu dengan tema: **konversi mata uang** (min. 3) dan **konversi waktu** (min. WIB, WIT, WITA, London).
- Minimal **2 sensor** (Accelerometer, Gyroscope, dll.) sesuai konsep.

**Kelompok & bahasa:** 1–3 orang, tema berbeda tiap kelompok, bahasa pemrograman yang mendukung teknologi dan komunikasi mobile.

**Presentasi & laporan:** presentasi tiap minggu setelah UTS. Laporan berisi Cover, Halaman Pengesahan, Daftar Isi, Landasan Teori & Tema, Perancangan (RBPL/RPL), Implementasi + penjelasan source code detail + screenshot, Lembar Evaluasi Pengujian. Laporan di-upload dan dicetak beserta halaman pengesahan sebagai syarat UAS.

---

## 2. Deskripsi Umum

**Storyloka** membantu pengguna mengelola koleksi buku pribadi, mencatat progres dan durasi membaca, menyimpan catatan, kutipan, dan ulasan, serta menjaga konsistensi kebiasaan membaca (target bulanan dan streak).

Aplikasi menggabungkan pencatatan buku dengan:
- **AI/LLM** untuk merangkum dan merekomendasikan buku,
- **Blockchain lokal (hash chain)** untuk sertifikat bukti bacaan,
- **Sensor** smartphone untuk interaksi (kocok untuk buku acak, tema otomatis),
- **LBS** untuk menemukan toko buku/perpustakaan terdekat,
- **Konverter** harga buku impor dan jadwal acara baca global,
- **Mini game** kuis literasi.

**Target pengguna:** pembaca yang ingin mencatat dan memotivasi kebiasaan membacanya.

### 2.1 Prinsip Rancangan
1. **Offline-first:** fitur inti (koleksi, sesi baca, catatan, blockchain) berjalan tanpa internet. Fitur online: pencarian buku online, AI, kurs, sinkronisasi.
2. **Keamanan sejak awal:** password di-hash dengan salt, database lokal terenkripsi, kunci disimpan di keystore perangkat, API key hanya di server.
3. **Konsisten dengan desain:** semua UI mengikuti `referensi_desain_ui_ux.md`.

---

## 3. Tech Stack (Keputusan Teknis)

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Framework | **Flutter (Dart)** | Satu basis kode Android & iOS |
| State management | Riverpod (atau Provider) | Pilih satu dan konsisten |
| Database lokal | `sqflite_sqlcipher` (SQLite terenkripsi AES-256) | Hive/SharedPreferences hanya untuk cache non-sensitif |
| Penyimpanan aman | `flutter_secure_storage` | Token sesi, kunci DB (Keychain/Keystore) |
| Hash password / SHA-256 | `cryptography` (Argon2id/PBKDF2), `crypto` (SHA-256) | Password tidak pernah disimpan polos |
| Biometrik | `local_auth` | Fingerprint / Face ID |
| Backend / web service | REST API sendiri (Node.js + Express, MySQL/PostgreSQL) | **Bukan Firebase** |
| Data buku | Google Books API / Open Library | Dipanggil dari klien atau lewat backend |
| LLM | Gemini API **lewat backend proxy** | API key tidak ada di aplikasi |
| Kurs | ExchangeRate API (via backend, di-cache) | Offline memakai cache terakhir |
| Peta / LBS | `flutter_map` + OpenStreetMap, `geolocator`, Overpass API | Gratis, tanpa billing |
| Notifikasi | `flutter_local_notifications` + `timezone` | Pengingat terjadwal lokal |
| Zona waktu | `timezone` (+ `flutter_timezone`) | DST London benar |
| Sensor | `sensors_plus` (accelerometer); sensor cahaya Android lewat paket/platform channel | Lihat Bagian 5.11 |
| Kamera/galeri | `image_picker` | Foto profil, cover buku |
| Barcode (opsional) | `mobile_scanner` | Pindai ISBN |

---

## 4. Matriks Pemenuhan Ketentuan (Traceability)

Kode `SCR-xx` ada di `referensi_desain_ui_ux.md`, `WF-xx` di `workflow_proyek.md`.

| ID | Ketentuan Dosen | Fitur Storyloka | Layar | Modul |
|---|---|---|---|---|
| F-01 | Login terenkripsi tanpa Firebase | Register/login dengan hash + salt, DB terenkripsi | SCR-01 | WF-02 |
| F-02 | Session | Token sesi + masa berlaku, auto-login, auto-expire | SCR-01, SCR-09 | WF-02 |
| F-03 | Login biometrik | Fingerprint/Face ID membuka kembali sesi | SCR-01, SCR-09 | WF-02 |
| F-04 | DB lokal | SQLite terenkripsi | semua | WF-03 |
| F-05 | DB online / web service | REST API: auth, sinkronisasi, backup, kesan | SCR-09, SCR-10 | WF-03 |
| F-06 | Bottom navigation | 5 slot: Beranda · Explore · Profil · Kesan · Logout | semua | WF-04 |
| F-07 | Menu profil (ada gambar) | Foto profil (kamera/galeri), statistik, pengaturan | SCR-09, SCR-17 | WF-04 |
| F-08 | Saran & kesan mata kuliah PAM | Dua kolom: Kesan dan Saran, tersimpan lokal + online | SCR-10 | WF-04 |
| F-09 | Menu logout | Dialog konfirmasi, hapus sesi | Dialog Logout | WF-02 |
| F-10 | Pencarian & pemilihan | Cari judul/penulis/ISBN, filter, sort, pilih hasil online | SCR-08, SCR-03, SCR-07 | WF-05 |
| F-11 | AI + LLM | Ringkasan, tanya-jawab, rekomendasi | SCR-05, SCR-06 | WF-07 |
| F-12 | Blockchain sederhana | Hash chain SHA-256 “Proof of Reading” | SCR-06 | WF-08 |
| F-13 | Mini game | Book Trivia + koin | SCR-04, SCR-16 | WF-09 |
| F-14 | Notifikasi mobile | Pengingat harian, target tercapai, sertifikat | SCR-14, SCR-09 | WF-06 |
| F-15 | Minimal 2 sensor | Accelerometer (shake) + sensor cahaya (auto-theme) | SCR-02, SCR-04, SCR-09 | WF-06 |
| F-16 | LBS | Toko buku/perpustakaan terdekat | SCR-04 | WF-06 |
| F-17 | Konversi mata uang (≥3) | IDR, USD, EUR, JPY | SCR-04 | WF-05 |
| F-18 | Konversi waktu | WIB, WITA, WIT, London | SCR-04 | WF-05 |
| F-19 | Fitur inti tema | Reading tracker: sesi stopwatch, progres, streak, target | SCR-02, SCR-15 | WF-05 |
| F-20 | (Opsional) | Scan barcode ISBN; lampirkan teks ke AI | SCR-07, SCR-05 | WF-05, WF-07 |

---

## 5. Spesifikasi Fitur Rinci

### 5.1 Autentikasi, Keamanan, Sesi (F-01–F-03, F-09)
- **Registrasi:** nama, email, password (min. 8 karakter). Password di-hash **Argon2id/PBKDF2 + salt unik per pengguna**; yang tersimpan hanya hash, salt, dan parameter KDF. Server juga menyimpan hash miliknya sendiri.
- **Login:** verifikasi hash (lokal untuk mode offline, server saat online). Pesan galat umum: “Email atau password salah”.
- **Session:** setelah login dibuat **session token** (acak, tidak dapat ditebak) dengan masa berlaku (default 7 hari), disimpan di `flutter_secure_storage`. Sesi kedaluwarsa → dialog “Sesi berakhir” lalu kembali ke login.
- **Enkripsi lokal:** SQLite dibuka dengan **kunci acak 256-bit yang dibuat saat registrasi** dan disimpan di Keychain/Keystore (bukan diturunkan dari password, agar login biometrik tetap dapat membuka database).
- **Biometrik:** dapat diaktifkan di Profil (diverifikasi saat mengaktifkan). Saat aplikasi dibuka dengan sesi valid dan biometrik aktif, pengguna wajib lolos biometrik. Gagal 3× → form password. Perangkat tanpa biometrik → opsi disembunyikan.
- **Logout:** hapus token sesi, tutup DB, bersihkan state memori, kembali ke SCR-01. Data buku lokal tetap tersimpan (terenkripsi).

### 5.2 Arsitektur Data (F-04, F-05)
**Tabel lokal (SQLite):**

| Tabel | Kolom utama |
|---|---|
| `users` | id, name, email, password_hash, salt, kdf_params, photo_path, created_at, updated_at |
| `books` | id, user_id, title, author, publisher, year, isbn, genre, pages, cover, synopsis, status (`wishlist`/`unread`/`reading`/`completed`), rating, price, started_at, finished_at, updated_at, deleted, dirty |
| `reading_sessions` | id, book_id, start_ts, duration_sec, last_page, note, updated_at |
| `notes_quotes` | id, book_id, type (`note`/`quote`), content, page, created_at |
| `reviews` | id, book_id, rating, text, created_at |
| `blocks` | idx, user_id, timestamp, book_id, review_hash, finished_date, previous_hash, hash |
| `feedback` | id, user_id, kesan, saran, updated_at, synced |
| `settings` | user_id, biometric_enabled, reminder_on, reminder_time, theme_mode, monthly_target, last_sync |
| `game_scores` | id, user_id, score, coins, played_at |
| `notifications` | id, user_id, type, title, body, ref, read, created_at |
| `rate_cache` | currency, rate_to_idr, fetched_at |

ERD final dibuat di laporan Bab Perancangan.

**API minimal (web service):**

| Endpoint | Fungsi |
|---|---|
| `POST /auth/register`, `POST /auth/login`, `POST /auth/logout` | Akun & sesi |
| `GET/POST/PUT/DELETE /books` | CRUD buku (opsional langsung) |
| `POST /sync` | Sinkronisasi dua arah (buku, sesi, catatan, blok, setting) |
| `POST /feedback`, `GET /feedback` | Kesan & saran |
| `POST /ai/chat`, `POST /ai/summarize`, `POST /ai/recommend` | Proxy LLM |
| `GET /rates` | Kurs (cache server) |

Sinkronisasi saat online; konflik: *last-write-wins* berdasarkan `updated_at`. Semua endpoint selain register/login memerlukan token sesi.

### 5.3 Navigasi (F-06–F-09)
Bottom navigation 5 slot tetap: **Beranda · Explore · Profil · Kesan · Logout** (rinci di dokumen desain Bagian 3). Library, AI Assistant, Sesi Membaca, Pencarian, dan Notifikasi diakses dari Beranda.

### 5.4 Library & Tracker (F-19)
- Koleksi dan Wishlist (SCR-03), tambah/edit buku (SCR-07), detail buku (SCR-06).
- **Sesi membaca (SCR-15):** stopwatch berbasis timestamp (akurat saat aplikasi di latar belakang), input halaman terakhir, simpan sesi → perbarui progres, total jam, streak, dan target bulanan.
- **Target bulanan** dapat diatur; **streak** bertambah bila ada sesi pada hari tersebut.
- Menandai buku selesai mewajibkan ulasan dan rating, lalu memicu blockchain.

### 5.5 Pencarian & Pemilihan (F-10)
- Pencarian lokal (judul, penulis, ISBN) dan online (Google Books/Open Library).
- Filter: genre, status, rating, tahun terbit. Sort: terbaru, judul, rating.
- **Pemilihan:** memilih hasil pencarian online → form tambah buku terisi otomatis → pilih status awal (Wishlist/Koleksi).

### 5.6 AI / LLM (F-11)
- **Ringkasan buku/bab** dari judul, penulis, sinopsis, dan catatan pengguna.
- **Asisten chat:** tanya jawab karakter/topik; konteks otomatis bila dibuka dari detail buku.
- **Rekomendasi buku mirip** berdasarkan genre dan rating riwayat bacaan.
- Lewat **backend proxy**; tangani loading, timeout, error, batas kuota, dan offline. Label “Dihasilkan AI” pada setiap jawaban. Hasil ringkasan di-cache lokal.
- Prompt sistem membatasi jawaban pada topik buku dan bahasa Indonesia.

### 5.7 Blockchain Sederhana: Proof of Reading (F-12)
Saat buku ditandai **Selesai**, dibuat satu blok:

```
Block {
  index, timestamp, book_id,
  review_hash   = SHA256(teks ulasan),
  finished_date, previous_hash,
  hash          = SHA256(index | timestamp | book_id | review_hash | finished_date | previous_hash)
}
```
- Blok pertama per pengguna = **Genesis Block** (`previous_hash` = 64 nol).
- **Validasi rantai:** hitung ulang `hash` tiap blok dan cocokkan `previous_hash`; hasil ✅ Valid / ❌ Tidak Valid (menunjuk blok yang rusak).
- **Sertifikat:** tampilan hash terpotong, tanggal selesai, dan **Bagikan Sertifikat** sebagai gambar.
- **Batasan (dicatat di laporan):** rantai lokal mendeteksi perubahan sebagian, tetapi tidak mencegah pemalsuan penuh. Mitigasi: kirim hash blok terakhir ke server saat sinkronisasi sebagai *anchor* pembanding.
- Ini hash chain lokal, **bukan** mata uang kripto/NFT.

### 5.8 Mini Game: Book Trivia (F-13)
- 10 soal pilihan ganda (tebak penulis/judul/genre) dari bank soal lokal + koleksi pengguna.
- Timer 15 detik/soal; skor → **koin**; skor tertinggi disimpan di `game_scores`.
- Dibuka dari segmen Game di Explore → SCR-16.

### 5.9 Notifikasi (F-14)
- **Pengingat Harian** pada jam pilihan (default 20:00) lewat penjadwalan lokal.
- Notifikasi **target tercapai**, **streak hampir putus**, dan **sertifikat diterbitkan**.
- Pusat Notifikasi (SCR-14) menyimpan riwayat; izin notifikasi diminta secara kontekstual (Android 13+ `POST_NOTIFICATIONS`); dapat dimatikan di Profil.

### 5.10 LBS (F-16)
GPS (izin runtime) → peta OpenStreetMap + penanda toko buku/perpustakaan/reading café (radius default 3 km) dengan jarak, status buka/tutup bila tersedia, dan tombol **Rute**. Tangani izin ditolak, GPS mati, dan offline.

### 5.11 Sensor (F-15)
| Sensor | Fitur | Aturan |
|---|---|---|
| **Accelerometer** (semua platform) | *Shake to Discover*: buku acak dari Wishlist | Magnitudo *user accelerometer* > 12 m/s² (atau mentah > ~25 m/s²), 2 guncangan dalam 600 ms, jeda 1,5 dtk; haptic feedback. Aktif di SCR-02 dan SCR-04; nonaktif saat sesi baca, kuis, dan input teks. Wishlist kosong → rekomendasi AI/online |
| **Sensor cahaya** (Android) | *Auto-Theme*: Dark Mode otomatis | Dark jika lux < 15 selama ≥ 2 dtk; Light jika lux > 40 selama ≥ 2 dtk (histeresis). Hanya bila tema = Otomatis |

⚠️ **Batasan platform:** iOS tidak memiliki API publik sensor cahaya. Di iOS, mode Otomatis memakai tema sistem (`platformBrightness`). Cantumkan di laporan. Alternatif sensor ke-2 yang tersedia di kedua platform: **Gyroscope**.

### 5.12 Konversi Mata Uang & Waktu (F-17, F-18)
- **Mata uang:** IDR, USD, EUR, JPY (≥3). Terpadu tema: input harga buku impor → hasil IDR (dan sebaliknya). Kurs dari API, di-cache untuk offline, tampilkan waktu pembaruan.
- **Waktu:** WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), London (UTC+0/+1 mengikuti DST). Terpadu tema: jadwal book club, read-a-thon, rilis buku global.

### 5.13 Saran & Kesan Mata Kuliah PAM (F-08)
Dua isian: **Kesan** dan **Saran** terhadap mata kuliah Pemrograman Aplikasi Mobile. Disimpan lokal dan dikirim ke web service; isi terakhir dapat diedit. Isi final ditulis oleh anggota kelompok sendiri.

---

## 6. Kebutuhan Non-Fungsional
- **Keamanan:** tidak ada password, token, atau API key *hardcoded*; HTTPS; data sensitif terenkripsi; validasi input klien dan server.
- **Performa:** layar utama muncul < 2 detik; daftar buku memakai *lazy loading*; 200 buku tetap lancar.
- **Keandalan:** offline-first, antrean sinkronisasi dengan percobaan ulang.
- **Aksesibilitas:** kontras ≥ 4,5:1, target sentuh ≥ 48 dp, label ikon.
- **Bahasa UI:** Indonesia.

---

## 7. Struktur Laporan Akhir

| No | Bagian | Isi & sumber |
|---|---|---|
| 1 | Cover | Judul, logo, nama & NIM, dosen, tahun |
| 2 | Halaman Pengesahan | Tanda tangan dosen (dicetak) |
| 3 | Daftar Isi | Otomatis |
| 4 | Landasan Teori & Tema Aplikasi | Personal library, arsitektur mobile, REST, LLM, blockchain/hash chain, enkripsi & hashing, biometrik, LBS, sensor |
| 5 | Perancangan (RBPL/RPL) | Use Case, ERD (Bagian 5.2), Class Diagram, Activity/Flow (`workflow_proyek.md` Bagian 3), wireframe (`referensi_desain_ui_ux.md`) |
| 6 | Implementasi & Source Code | Penjelasan per modul WF-02–WF-09, kode kunci, **screenshot** tiap SCR-xx |
| 7 | Lembar Evaluasi Pengujian | Black-box (`workflow_proyek.md` Bagian 6), performance testing |

Kumpulkan laporan, unggah, dan cetak bersama halaman pengesahan sebelum UAS. Presentasi dilakukan tiap minggu setelah UTS.

---

## Lampiran A: Identitas Kelompok
| Nama | NIM | Peran |
|---|---|---|
| (isi) | (isi) | (mis. Frontend / Backend / Laporan) |

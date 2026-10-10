# Referensi Desain UI/UX & Layout: Storyloka

> **📌 DOKUMEN RUJUKAN WAJIB (baca bersama file ini)**
> | Kebutuhan | File |
> |---|---|
> | Ketentuan dosen, fitur F-xx, tech stack, model data | [`deskripsi_proyek.md`](./deskripsi_proyek.md) |
> | Urutan kerja, alur sistem, standar kode, pengujian | [`workflow_proyek.md`](./workflow_proyek.md) |
> | Prototipe visual interaktif (5 layar awal) | [`prototipe_ui_storyloka.html`](./prototipe_ui_storyloka.html) |
>
> **Aturan:** semua layar WAJIB memakai design tokens (Bagian 1), Master Layout (Bagian 2), dan komponen (Bagian 8). Setiap layar punya kode **SCR-xx** yang dirujuk dari matriks fitur dan workflow. Jangan membuat layar baru tanpa mendaftarkannya di Katalog (Bagian 5).
>
> **Status prototipe HTML:** prototipe hanya mencakup 5 layar dan **menjadi sumber gaya visual** (indigo/slate, kartu membulat, font Inter). Bila berbeda dengan dokumen ini (mis. bottom nav, layar Profil), **dokumen ini yang berlaku**.

Aplikasi: **Storyloka**, Personal Book Library & Reading Tracker. Spesifikasi ini dapat dipakai sebagai acuan coding Flutter dan bahan Bab Perancangan laporan.

---

## 1. Design Tokens

### 1.1 Palet Warna (Indigo/Slate)

| Token | Light | Dark | Penggunaan |
|---|---|---|---|
| `primary-500` | `#6366F1` | `#818CF8` | Brand, tombol utama, tab aktif |
| `primary-600` | `#4F46E5` | `#6366F1` | Pressed/hover; **teks atau tombol kecil di atas putih** |
| `primary-50` | `#EEF2FF` | `#1E1B4B` | Latar kartu aktif / highlight |
| `secondary-500` | `#8B5CF6` | `#A78BFA` | Aksen AI/LLM, blockchain, badge |
| `bg` | `#F8FAFC` | `#0F172A` | Latar layar |
| `surface` | `#FFFFFF` | `#1E293B` | Kartu, bottom sheet, navbar |
| `neutral-100` | `#F1F5F9` | `#334155` | Divider, bubble AI, input terisi |
| `neutral-200` | `#E2E8F0` | `#475569` | Border, dasar shimmer |
| `neutral-500` | `#64748B` | `#94A3B8` | Teks sekunder, placeholder, ikon non-aktif |
| `text-primary` | `#0F172A` | `#F1F5F9` | Teks utama |
| `success-500` | `#10B981` | `#34D399` | Selesai, blockchain valid |
| `warning-500` | `#F59E0B` | `#FBBF24` | Peringatan, wishlist, pending |
| `danger-500` | `#EF4444` | `#F87171` | Error, hapus, logout |

Aturan kontras: teks kecil (< 18sp) di atas `primary-500` memakai `primary-600` atau berat tebal; target semua teks ≥ 4,5:1 (WCAG AA).

### 1.2 Tipografi
Font **Inter** (di-*bundle* sebagai aset, tidak diunduh saat runtime).

| Gaya | Ukuran / Berat / Line height |
|---|---|
| H1 Display | 24sp / Bold / 32 |
| H2 Section | 18sp / SemiBold / 24 |
| H3 Card Title | 15sp / SemiBold / 20 |
| Body 1 | 14sp / Regular / 20 |
| Body 2 | 12sp / Regular / 16 |
| Caption | 11sp / Medium / 14 |
| Angka stopwatch | 40sp / Bold / monospace (tabular figures) |

### 1.3 Spacing, Radius, Elevasi
- Grid dasar **8dp** (mikro 4dp). Margin layar **16dp**. Padding kartu **16dp**. Jarak antar kartu **12dp**.
- Touch target minimum **48×48dp**.
- Radius: Small `8` (badge, tombol kecil) · Medium `12` (kartu, input, tombol) · Large `20` (bottom sheet) · Pill `999`.
- Elevasi: kartu Light `0 2 8 rgba(15,23,42,0.06)`; Dark tanpa shadow, memakai border `neutral-200` (dark).
- Ikon: Material Symbols / Lucide (garis, *rounded*). Emoji pada wireframe hanya penanda.

### 1.4 State Komponen
Default · pressed · disabled (opacity 40%) · focus (ring `primary-500` 2dp) · loading (spinner, tombol nonaktif) · error (border `danger-500` + pesan 12sp di bawah field).

### 1.5 Perilaku Tema
Tiga mode: **Otomatis (Sensor)** · Terang · Gelap. Mode manual mengabaikan sensor. Aturan sensor di Bagian 4.

---

## 2. Master Layout (4 Zona)

```
+----------------------------------------------+
| ZONA 1: TOP BAR (judul / sapaan / aksi)      |  tinggi 56dp
+----------------------------------------------+
| ZONA 2: KONTEN (scroll, berbasis kartu)      |  padding 16dp, ruang bawah 88dp
|  - Kartu ringkasan / header                  |
|  - Modul fitur utama                         |
|  - Kartu aksi sekunder                       |
+----------------------------------------------+
|                          ZONA 3: FAB [ + ]   |  opsional, 56dp, kanan,
+----------------------------------------------+  16dp di atas bottom nav
| ZONA 4: BOTTOM NAV (5 slot)                  |  tinggi 64dp + safe area
+----------------------------------------------+
```

| Zona | Aturan |
|---|---|
| Zona 1 | Kiri: sapaan/judul/tombol `←`. Kanan: maksimal 2 ikon aksi. Sticky saat scroll. |
| Zona 2 | `ListView` / `SingleChildScrollView`; semua kelompok data dibungkus **StorylokaCard**. |
| Zona 3 | Hanya SCR-03 (**+ Tambah Buku**). Layar lain tanpa FAB. |
| Zona 4 | Tampil di layar utama saja (Bagian 3.3). Layar fokus menyembunyikannya dan memakai tombol `← Kembali`. |

---

## 3. Navigasi

### 3.1 Bottom Navigation (5 slot)

| Slot | Label | Tujuan | Catatan |
|---|---|---|---|
| 1 | Beranda | SCR-02 | Titik masuk ke Library, AI, Sesi Membaca, Notifikasi |
| 2 | Explore | SCR-04 | LBS, Konverter, Game |
| 3 | Profil | SCR-09 | Menu profil (ada gambar) |
| 4 | Kesan | SCR-10 | Saran & kesan mata kuliah PAM |
| 5 | Logout | Dialog konfirmasi | Ikon `danger-500`; bukan layar |

Indikator aktif: ikon + label `primary-500` dan pil `primary-50`. Label selalu tampil.

### 3.2 Jalur Akses Layar Lain
| Layar | Dari mana |
|---|---|
| SCR-03 Library & Wishlist | Beranda → Aksi Cepat (Koleksi/Wishlist) atau My Collection → Lihat semua |
| SCR-05 AI Assistant | Beranda → Aksi Cepat "AI Assistant"; SCR-06 → "Tanya AI" |
| SCR-06 Detail Buku | Ketuk buku di SCR-03 / SCR-08 / Beranda |
| SCR-07 Tambah/Edit Buku | FAB di SCR-03; Aksi Cepat "Tambah"; "Edit" di SCR-06; "Pilih" di SCR-08 |
| SCR-08 Pencarian | Ikon cari di Beranda & SCR-03; Aksi Cepat "Cari" |
| SCR-14 Notifikasi | Ikon lonceng di header Beranda |
| SCR-15 Sesi Membaca | "Mulai Baca" pada kartu Currently Reading |
| SCR-16 Permainan | Segmen Game di SCR-04 |
| SCR-17 Edit Profil | Avatar/ikon edit di SCR-09 |

### 3.3 Bottom Nav Tampil / Sembunyi
- **Tampil:** SCR-02, 03, 04, 09, 10, 14.
- **Disembunyikan (layar fokus):** SCR-01, 05, 06, 07, 08, 15, 16, 17.

### 3.4 Alur Utama
```
SCR-01 Splash ─(sesi valid + biometrik)─► Verifikasi biometrik ─► SCR-02
     │          (sesi valid, tanpa biometrik) ─────────────────► SCR-02
     └─(tidak ada sesi / kedaluwarsa)─► Login / Register ──────► SCR-02

SCR-02 Beranda ─► SCR-03 Library ─► SCR-06 Detail ─► SCR-07 Edit
   ├─► SCR-05 AI Assistant              └─► Sertifikat (blockchain)
   ├─► SCR-15 Sesi Membaca
   ├─► SCR-08 Pencarian ─► SCR-07 Tambah
   └─► SCR-14 Notifikasi
SCR-04 Explore ─► (Peta | Konverter | Game) ─► SCR-16 Permainan
SCR-09 Profil ─► SCR-17 Edit Profil
Slot Kesan ─► SCR-10        Slot Logout ─► Dialog ─► SCR-01 (sesi dihapus)
```

---

## 4. Sensor & Perilaku Adaptif

**Ambient Light → Auto-Theme (sensor 1)**
- Masuk Dark Mode jika lux **< 15** selama ≥ 2 dtk; kembali Light jika lux **> 40** selama ≥ 2 dtk (histeresis agar tidak berkedip). Hanya saat tema = Otomatis.
- **Android:** sensor cahaya. **iOS:** tidak ada API publik → ikuti tema sistem. Cantumkan di laporan sebagai batasan platform.

**Accelerometer → Shake to Discover (sensor 2)**
- Gunakan magnitudo *user accelerometer* (tanpa gravitasi) > **12 m/s²**, atau accelerometer mentah > **~25 m/s²** (≈ 2,5 g). Ambang 13 m/s² pada data mentah terlalu rendah karena gravitasi diam sudah 9,8 m/s².
- Syarat: 2 guncangan dalam 600 ms, lalu jeda 1,5 dtk. Efek: haptic + modal **1 buku acak dari Wishlist** (kosong → rekomendasi AI/online).
- Aktif di SCR-02 dan SCR-04; nonaktif saat sesi baca, kuis, dan saat mengetik.
- Alternatif sensor ke-2 lintas platform: Gyroscope.

---

## 5. Katalog Layar

| Kode | Layar | Fitur | Bottom nav | FAB |
|---|---|---|---|---|
| SCR-01 | Splash, Register, Login & Biometrik | F-01–F-03 | – | – |
| SCR-02 | Beranda, Ringkasan & Currently Reading | F-15, F-19 | ✔ (Beranda) | – |
| SCR-03 | Library: Koleksi & Wishlist | F-10 | ✔ (Beranda) | + Tambah Buku |
| SCR-04 | Explore: Peta (LBS), Konverter, Game | F-13, F-15–F-18 | ✔ (Explore) | – |
| SCR-05 | AI / LLM Assistant | F-11 | – | – |
| SCR-06 | Detail Buku & Blockchain | F-11, F-12 | – | – |
| SCR-07 | Tambah / Edit Buku | F-10, F-20 | – | – |
| SCR-08 | Pencarian & Filter | F-10 | – | – |
| SCR-09 | Profil, Pengaturan & Keamanan | F-02, F-03, F-07, F-14 | ✔ (Profil) | – |
| SCR-10 | Saran & Kesan Mata Kuliah PAM | F-08 | ✔ (Kesan) | – |
| SCR-11 | State: Loading (Skeleton) | – | ikut layar | – |
| SCR-12 | State: Kosong | – | ikut layar | – |
| SCR-13 | State: Error & Offline | – | ikut layar | – |
| SCR-14 | Pusat Notifikasi | F-14 | ✔ (Beranda) | – |
| SCR-15 | Sesi Membaca (Stopwatch) | F-19 | – | – |
| SCR-16 | Permainan Book Trivia | F-13 | – | – |
| SCR-17 | Edit Profil | F-07 | – | – |
| – | Dialog Logout | F-09 | slot Logout | – |

---

## 6. Spesifikasi & Wireframe per Layar

> **[Wajib]** dari ketentuan dosen / inti tema; **[Opsional]** nilai tambah, dikerjakan bila waktu cukup.

### SCR-01: Splash, Register, Login & Biometrik [Wajib]
```
+----------------------------------------------+
|                 [ Logo 80dp ]                |
|                  Storyloka                   |
|     Temukan, Simpan, & Lacak Bacaanmu        |
|  +----------------------------------------+  |
|  |  [ Masuk ]   [ Daftar ]   (tab)        |  |
|  |  Email / Username  [________________]  |  |
|  |  Password          [______________][👁] |  |
|  |  [            MASUK             ]      |  |
|  |  ──────── atau ────────                |  |
|  |  [ 🔐 Masuk dengan Biometrik ]         |  |
|  +----------------------------------------+  |
+----------------------------------------------+
```
- **Splash (1,5 dtk):** logo + cek sesi; rute sesuai diagram 3.4.
- **Login:** Email/Username, Password (tampil/sembunyi), tombol **Masuk**. **Register:** Nama lengkap, Email, Password (min. 8 karakter, indikator kekuatan), Konfirmasi, tombol **Daftar**.
- Validasi inline; pesan umum “Email atau password salah”.
- **Biometrik:** tombol hanya tampil bila sudah diaktifkan di Profil dan sesi tersimpan. Gagal 3× → form password. Perangkat tanpa biometrik → tombol disembunyikan.
- Sesi kedaluwarsa → dialog “Sesi berakhir, silakan masuk lagi”.

### SCR-02: Beranda, Ringkasan & Currently Reading [Wajib]
```
+----------------------------------------------+
| Halo, Nama                       [🔔•]  (Avt) | <- Zona 1
+----------------------------------------------+
| +------------------------------------------+ |
| | Reading Summary           (primary-500)  | |
| | [ 12 Dibaca ]    [ 28 Selesai ]          | |
| | 🔥 5 hari   Target bulan ini 4/5         | |
| | [==============>        ] 80%            | |
| +------------------------------------------+ |
| Currently Reading                            |
| +------------------------------------------+ |
| | [Cover]  Atomic Habits       [ Mulai     ]| |
| |          James Clear         [ Baca      ]| |
| |          [=====>        ] 45%            | |
| +------------------------------------------+ |
| Aksi Cepat                                   |
| [Koleksi][Wishlist][AI][Tambah][Cari]        |
| My Collection                    Lihat semua |
| [Cover][Cover][Cover] ──►                    |
+----------------------------------------------+
| Beranda | Explore | Profil | Kesan | Logout  | <- Zona 4
+----------------------------------------------+
```
- **Header:** “Halo, [Nama]”, avatar (foto profil), lonceng (titik merah bila ada notifikasi belum dibaca) → SCR-14.
- **Reading Summary Card** (`primary-500`): Buku Dibaca, Buku Selesai, 🔥 Streak, Target bulan ini + progress bar.
- **Currently Reading Card:** cover, judul, penulis, progress bar %, tombol **Mulai Baca** → SCR-15.
- **Aksi Cepat:** Koleksi · Wishlist · AI Assistant · Tambah Buku · Cari.
- **My Collection:** carousel horizontal + “Lihat semua” → SCR-03.
- State: kosong (SCR-12), skeleton (SCR-11), error (SCR-13). Sensor: shake aktif.

### SCR-03: Library, Koleksi & Wishlist [Wajib]
```
+----------------------------------------------+
| Library                          [🔍] [≡/▦]  |
| [ Koleksi Saya ] [ Wishlist ]   (segmented)  |
| [🔎 cari singkat......] [Filter] [Sort ▾]    |
| +--------------+  +--------------+           |
| |   [Cover]    |  |   [Cover]    |           |
| | Judul (2 br) |  | Judul        |           |
| | Penulis      |  | Penulis      |           |
| | ★★★★☆ [Badge]|  | ★★★☆☆ [Badge]|           |
| +--------------+  +--------------+           |
|                                  [ + ]  <FAB |
+----------------------------------------------+
```
- Grid 2 kolom, cover rasio 2:3, judul maks 2 baris, penulis, rating, badge status. Toggle Grid/List. Sort: Judul, Penulis, Terbaru.
- Ketuk → SCR-06; *long press* → Action Sheet: `Edit`, `Pindahkan ke Koleksi/Wishlist`, `Hapus` (dengan konfirmasi). FAB → SCR-07.

### SCR-04: Explore: LBS, Konverter & Game [Wajib]
```
+----------------------------------------------+
| Explore                                      |
| [ Peta ]  [ Konverter ]  [ Game ]  (segmen)  |
| +------------------------------------------+ |
| |        [ PETA OSM + marker ]             | |
| +------------------------------------------+ |
| 📍 Toko Buku A   800 m   Buka  [Rute]        |
| 📍 Perpustakaan  1,5 km        [Rute]        |
+----------------------------------------------+
```
**Segmen Peta (LBS):** OpenStreetMap (`flutter_map`); marker toko buku/perpustakaan/reading café radius 3 km; kartu: nama, jarak, status buka/tutup, tombol **Rute**. State: izin ditolak (kartu ajakan + **Buka Pengaturan**), GPS mati, offline.

**Segmen Konverter** (terpadu tema buku):
- *Mata uang:* **IDR, USD, EUR, JPY**. Input harga buku impor → hasil IDR (dan sebaliknya). Tampilkan “diperbarui [waktu]”; cache untuk offline.
- *Waktu:* **WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), London (UTC+0/+1, DST)**. Pilih tanggal/jam acuan → keempat zona. Konteks: “Jadwal book club / read-a-thon / rilis buku global”.

**Segmen Game:** kartu “Book Trivia Challenge”, skor tertinggi, koin → **Mainkan** → SCR-16. Shake aktif di layar ini.

### SCR-05: AI / LLM Assistant [Wajib]
```
+----------------------------------------------+
| [←]  Storyloka AI              (Online) ✨   |
| [✨ Ringkasan] [📚 Buku Mirip] [❓ Jelaskan]  |
|                     +--------------------+   |
|                     | Ringkas bab 3      |   | <- user, primary-500
|                     +--------------------+   |
| +--------------------+                       |
| | Bab ini membahas...|  Dihasilkan AI        | <- AI, neutral-100
| +--------------------+                       |
| [ Tulis pertanyaan...            ] [Kirim]   |
+----------------------------------------------+
```
- Quick Action: Ringkasan Buku/Bab · Rekomendasi Buku Mirip · Jelaskan Topik/Karakter.
- Konteks otomatis (judul & catatan) bila dibuka dari SCR-06. **[Opsional]** tombol lampirkan teks/dokumen.
- State: AI mengetik (tiga titik), error/timeout → **Coba Lagi**, kuota habis → pesan jelas, offline → input dinonaktifkan.

### SCR-06: Detail Buku & Blockchain Proof-of-Reading [Wajib]
```
+----------------------------------------------+
| [←]  Detail Buku                    [⋮]      |
| +------------------------------------------+ |
| | [Cover 120x180]  Laskar Pelangi          | |
| |                  Andrea Hirata · 2005    | |
| |                  Genre · 529 hal · ★ 4,9 | |
| |                  [Badge Status] [Ubah]   | |
| +------------------------------------------+ |
| Sinopsis ........................ Selengkapnya|
| Catatan & Kutipan             [+ Tambah]     |
| Ulasan & Rating                              |
| +------------------------------------------+ |
| | ✨ AI: [Ringkas dengan AI] [Tanya AI]    | |
| +------------------------------------------+ |
| +------------------------------------------+ |
| | 🔗 Terverifikasi (Hash Chain Lokal)      | |
| | Blok #3  8f4a…e91c   12-10-2026          | |
| | [Validasi Rantai]  [Bagikan Sertifikat]  | |
| +------------------------------------------+ |
+----------------------------------------------+
```
- Info: cover, judul, penulis, penerbit, tahun, ISBN, genre, halaman, rating. Aksi: `Ubah Status`, `Edit`, `Hapus`.
- **Kartu Blockchain** hanya jika status *Selesai*: badge `success-500`, nomor blok, hash SHA-256 terpotong, `previous_hash`, tanggal selesai. **Validasi Rantai** → ✅ Valid / ❌ Tidak Valid. **Bagikan Sertifikat** → gambar.
- Menandai selesai: dialog konfirmasi → wajib ulasan & rating → buat blok → notifikasi “Sertifikat diterbitkan”.

### SCR-07: Tambah / Edit Buku [Wajib; scan barcode Opsional]
- **Sumber:** manual atau **Cari Online** (pilih hasil → form terisi otomatis). **[Opsional]** `Pindai Barcode ISBN` (izin kamera, viewfinder overlay).
- **Form:** cover (kamera/galeri/URL), judul*, penulis*, penerbit, jumlah halaman*, genre, tahun terbit, harga (opsional), status (Wishlist / Belum Dibaca / Sedang Dibaca / Selesai).
- Validasi: field bertanda * wajib; halaman > 0. Tombol **Simpan Buku** (`primary-500`) dan **Batal**.

### SCR-08: Pencarian & Filter [Wajib]
```
+----------------------------------------------+
| [🔍 Cari judul / penulis / ISBN......] Batal |
| [ Koleksi Saya ] [ Cari Online ]             |
| [Genre ▾][Status ▾][★ 4+][Tahun ▾]  Reset    |
| [Cover] Judul / Penulis / Tahun   [Pilih]    |
| [Cover] Judul / Penulis / Tahun   [+ Wishlist]|
+----------------------------------------------+
```
- Filter lengkap di bottom sheet: Genre, Status, Rating, **Tahun terbit**, Urutkan (Terbaru/Judul/Rating) + `Reset`.
- Aksi cepat hasil: `Pilih` (→ SCR-07 terisi) / `+ Wishlist` / `+ Koleksi`.
- State: tidak ada hasil, skeleton, error, offline (hanya koleksi lokal).

### SCR-09: Profil, Pengaturan & Keamanan [Wajib]
```
+----------------------------------------------+
| Profil                                       |
| +------------------------------------------+ |
| |        ( Foto 72dp )  ✎                  | |
| |        Nama Pengguna                     | |
| |        email@contoh.com  [Level Pembaca] | |
| |  28 Buku · 96 Jam · 5 Sertifikat · 120🪙 | |
| +------------------------------------------+ |
| Keamanan & Sesi                              |
|  🔐 Login Biometrik            [ ON/OFF ]    |
|  🔒 Enkripsi Lokal (AES-256)   Aktif         |
|  ⏳ Sesi berlaku hingga ...                  |
| Notifikasi                                   |
|  🔔 Pengingat Harian  [ON]   Jam [20:00]     |
|  🎯 Notifikasi target & streak [ON]          |
| Tampilan                                     |
|  🌓 Tema [ Otomatis (Sensor) | Terang | Gelap ]|
| Data                                         |
|  ☁️ Sinkronkan Sekarang   Terakhir: ...      |
+----------------------------------------------+
```
- Header profil (**ada gambar**): avatar → SCR-17. Statistik: total buku dibaca, jam baca, sertifikat, koin game.
- Toggle biometrik meminta verifikasi biometrik saat diaktifkan.
- **Tidak ada tombol Logout di sini**; logout ada di bottom nav.

### SCR-10: Saran & Kesan Mata Kuliah PAM [Wajib]
```
+----------------------------------------------+
| Kesan & Saran Mata Kuliah                    |
| Pemrograman Aplikasi Mobile                  |
| +------------------------------------------+ |
| | 💬 Kesan terhadap mata kuliah PAM        | |
| | [ textarea ........................... ] | |
| +------------------------------------------+ |
| +------------------------------------------+ |
| | 💡 Saran untuk perkuliahan PAM           | |
| | [ textarea ........................... ] | |
| +------------------------------------------+ |
| [          SIMPAN / KIRIM          ]         |
+----------------------------------------------+
```
- Dua kartu textarea. Simpan lokal dan kirim ke web service; isi terakhir tampil ulang dan dapat diedit. Validasi: minimal satu kolom terisi.

### SCR-11: State Loading (Skeleton)
Shimmer `neutral-200` → `neutral-100` (Dark: `#475569` → `#334155`), 1,2 dtk. Cover → blok 2:3; teks → garis lebar 70% dan 40%. Dipakai di SCR-02, 03, 04, 05, 08.

### SCR-12: State Kosong
Ilustrasi lembut, judul (“Belum Ada Buku di Koleksi”), deskripsi, CTA `Cari Buku` / `Tambah Buku Baru`. Varian: Wishlist, hasil cari, notifikasi, riwayat sesi.

### SCR-13: State Error & Offline
Ikon `danger-500`, pesan (“Koneksi Terputus” / “Gagal Memuat Data”), CTA `Coba Lagi` dengan indikator loading. **Banner offline** tipis di atas konten; fitur lokal tetap berfungsi.

### SCR-14: Pusat Notifikasi [Wajib]
- Header “Pusat Notifikasi” + `Tandai Semua Dibaca`.
- Daftar (ikon, judul, waktu, titik belum dibaca): Pengingat Harian, Target/Streak, Sertifikat Blockchain, Rekomendasi AI. Ketuk → layar terkait (SCR-06 atau SCR-15).
- Notifikasi sistem dijadwalkan lokal; izin diminta secara kontekstual.

### SCR-15: Sesi Membaca (Stopwatch) [Wajib untuk tracker]
```
+----------------------------------------------+
| [←]  Sesi Membaca                            |
| [Cover kecil]  Atomic Habits                 |
|          00:24:15                            |
|        WAKTU MEMBACA                         |
|     [ Jeda ]    [ Lanjut ]                   |
| Halaman terakhir:  [ − ] 45 [ + ]  / 320 hal |
| Catatan / kutipan cepat (opsional) [.....]   |
| [      SELESAI & SIMPAN SESI      ]          |
+----------------------------------------------+
```
- **Teknis:** simpan `start_timestamp`, hitung durasi dari selisih waktu (bukan penghitung per detik) agar akurat di latar belakang.
- Keluar tanpa menyimpan → konfirmasi. Simpan → perbarui progres, total jam, streak, target; halaman = total → alur *tandai selesai* (SCR-06).

### SCR-16: Permainan Book Trivia [Wajib]
- Tanpa bottom nav. Progress soal (3/10), timer lingkaran 15 dtk, kartu pertanyaan, 4 pilihan.
- Benar `success-500`; salah `danger-500` + jawaban benar ditampilkan.
- Hasil: skor, koin, **Main Lagi / Kembali**. Skor tertinggi disimpan lokal. Soal dari bank soal lokal + koleksi pengguna.

### SCR-17: Edit Profil [Wajib untuk foto profil]
Ganti foto (kamera/galeri, dengan izin), ubah nama, ganti password (verifikasi password lama). Tombol **Simpan**.

### Dialog Logout [Wajib]
“Keluar dari Storyloka? Sesi akan diakhiri.” `Batal` / `Keluar` (`danger-500`). Aksi: hapus token, tutup DB terenkripsi, bersihkan state memori, kembali ke SCR-01. Data buku lokal tetap tersimpan (terenkripsi).

---

## 7. Model Status Buku (Konsisten di Semua Layar)

| Status | Muncul di | Badge |
|---|---|---|
| `wishlist` | Tab Wishlist | `warning-500` |
| `unread` (Belum Dibaca) | Tab Koleksi | `neutral-500` |
| `reading` (Sedang Dibaca) | Tab Koleksi, Currently Reading | `primary-500` |
| `completed` (Selesai) | Tab Koleksi, memicu blockchain | `success-500` |

---

## 8. Komponen Reusable

| Komponen | Spesifikasi |
|---|---|
| **StorylokaCard** | `surface`, radius 12, padding 16, elevasi Bagian 1.3. Semua kelompok data dibungkus kartu. |
| **TopBar** | 56dp, sticky, maks 2 aksi. |
| **BottomNavBar** | 5 slot, label selalu tampil, aktif `primary-500` + pil `primary-50`; slot Logout `danger-500`. |
| **FAB** | 56dp, hanya SCR-03. |
| **StatusBadge** | Pil, warna sesuai Bagian 7. |
| **PrimaryButton / SecondaryButton** | Tinggi 48, radius 12; Secondary = outline `primary-600`. |
| **BookCover** | Rasio 2:3, radius 8, placeholder bila kosong. |
| **SegmentedControl** | SCR-03 (Koleksi/Wishlist), SCR-04 (Peta/Konverter/Game). |
| **EmptyState / ErrorState / LoadingSkeleton** | Wajib di setiap layar berdata (SCR-11–13). |

Pemetaan kode: `core/theme` (token), `core/widgets` (komponen), `features/<nama>` (layar), lihat `workflow_proyek.md` Bagian 4.2.

---

## 9. Pemetaan Ketentuan Dosen → Layar

| Ketentuan | Layar |
|---|---|
| AI + LLM | SCR-05, SCR-06 |
| Mini game | SCR-04 (Game), SCR-16 |
| Pencarian & pemilihan | SCR-08, SCR-03, SCR-07 |
| Notifikasi mobile | SCR-14, SCR-09 |
| Blockchain sederhana | SCR-06 |
| Login terenkripsi + session | SCR-01, SCR-09 |
| Login biometrik | SCR-01, SCR-09 |
| DB lokal + online / web service | semua layar; sinkronisasi di SCR-09 |
| LBS | SCR-04 (Peta) |
| Bottom nav: profil (gambar), kesan, logout | Bagian 3.1, SCR-09, SCR-10, Dialog Logout |
| Konversi mata uang (≥3) & waktu | SCR-04 (Konverter) |
| Minimal 2 sensor | Bagian 4 |

---

## 10. Checklist Implementasi per Layar
- [ ] Memakai token warna/tipografi/spacing, tanpa nilai hard-coded.
- [ ] Light & Dark Mode tampil benar.
- [ ] State loading, kosong, error/offline tersedia.
- [ ] Touch target ≥ 48dp, kontras ≥ 4,5:1.
- [ ] Bottom nav tampil/sembunyi sesuai Bagian 3.3.
- [ ] Izin platform diminta secara kontekstual (lokasi, kamera, notifikasi, biometrik).
- [ ] Screenshot (Light & Dark) disimpan untuk laporan.
- [ ] Layar baru didaftarkan di Katalog (Bagian 5).

---

## Lampiran: Perubahan dari Prototipe/Spesifikasi Awal
| Awal | Sekarang | Alasan |
|---|---|---|
| Bottom nav: Home, Library, Tambah, Timer, Profile | Beranda, Explore, Profil, Kesan, Logout | Ketentuan dosen |
| Kesan/saran menilai aplikasi (“PAM = Penilaian Akademik”) | Kesan & saran untuk mata kuliah **Pemrograman Aplikasi Mobile** | Sesuai tugas |
| Blockchain: hash `0x…`, NFT | Hash chain SHA-256 lokal + validasi | Blockchain sederhana |
| Shake > 13 m/s² data mentah | Aturan Bagian 4 | Gravitasi diam sudah 9,8 m/s² |
| Light sensor tanpa catatan platform | Fallback iOS + histeresis | iOS tanpa API publik |
| Explore menumpuk peta, konverter, game | 3 segmen + SCR-16 | Layar terlalu padat |
| Stopwatch panel melayang di Beranda | SCR-15 berbasis timestamp | Akurasi di latar belakang |
| Filter “Harga: Free/Paid” | Genre, Status, Rating, Tahun | Lebih relevan |
| Google Maps/Mapbox | OpenStreetMap (opsional lainnya) | Tanpa API key/billing |

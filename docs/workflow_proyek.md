# Workflow Proyek & Alur Sistem: Storyloka

> **📌 DOKUMEN RUJUKAN WAJIB (baca bersama file ini)**
> | Kebutuhan | File |
> |---|---|
> | Ketentuan dosen, fitur F-xx, tech stack, model data, API | [`deskripsi_proyek.md`](./deskripsi_proyek.md) |
> | Layout, design tokens, layar SCR-xx, komponen | [`referensi_desain_ui_ux.md`](./referensi_desain_ui_ux.md) |
>
> **Aturan:** setiap modul WF-xx mengerjakan fitur F-xx dan layar SCR-xx yang tercantum. Modul dinyatakan selesai hanya jika memenuhi **Definition of Done** (Bagian 5).

---

## 1. Gambaran Alur Kerja

```
Baca ketentuan (deskripsi) → Patuhi desain (referensi UI/UX) → WF-01 Setup
   → WF-02…WF-09 (satu modul = satu cabang Git) → WF-10 Testing → WF-11 Laporan & Presentasi
```
Prinsip: **offline-first**, **desain dipatuhi sebelum berkreasi**, **fitur wajib dulu, opsional belakangan**.

---

## 2. Roadmap & Modul Kerja

| Minggu | Modul | Fitur | Layar | Output yang diverifikasi |
|---|---|---|---|---|
| 1 | **WF-01** Setup & Fondasi | – | – | Proyek Flutter berjalan, tema (token), struktur folder, skema SQLite, repo Git, backend kosong terhubung |
| 2 | **WF-02** Auth, Session, Biometrik, Logout | F-01–F-03, F-09 | SCR-01, Dialog Logout | Register/login terenkripsi, sesi, biometrik, logout |
| 2 | **WF-03** Data Lokal & Online | F-04, F-05 | semua | CRUD offline, REST API, sinkronisasi dasar |
| 2 | **WF-04** Navigasi, Profil, Kesan | F-06–F-08 | SCR-09, 10, 17 | Bottom nav 5 slot, foto profil, form kesan |
| 2–3 | **WF-05** Library, Tracker, Pencarian, Konverter | F-10, F-17–F-19 | SCR-02, 03, 06, 07, 08, 15, 04 (Konverter) | CRUD buku, sesi baca, filter, kurs & zona waktu |
| 3 | **WF-06** Sensor, LBS, Notifikasi | F-14–F-16 | SCR-02, 04, 09, 14 | Shake, auto-theme, peta, reminder |
| 4 | **WF-07** AI / LLM | F-11 | SCR-05, 06 | Ringkasan, chat, rekomendasi via backend |
| 4 | **WF-08** Blockchain | F-12 | SCR-06 | Blok saat selesai, validasi rantai, sertifikat |
| 4 | **WF-09** Mini Game | F-13 | SCR-04 (Game), 16 | Kuis, skor, koin |
| 5 | **WF-10** Testing | semua | semua | Tabel test case terisi, bug kritis nol |
| 5 | **WF-11** Laporan & Presentasi | – | – | Laporan sesuai 7 bagian, demo siap |

> Presentasi berlangsung tiap minggu setelah UTS: pastikan **setiap akhir minggu ada build yang bisa didemokan**, urutan modul di atas dirancang agar demikian.

---

## 3. Alur Sistem

### 3.1 Start Aplikasi & Sesi (WF-02)
```
Start → SCR-01 Splash → Token ada & belum kedaluwarsa?
   Tidak → Login / Register
   Ya    → Biometrik aktif?
              Ya    → Verifikasi biometrik → sukses? Ya → SCR-02 | gagal 3× → Login password
              Tidak → SCR-02
```

### 3.2 Register, Login, Logout (WF-02)
```
Register: input → validasi → salt + hash (Argon2id/PBKDF2) → buat kunci DB acak → simpan di Secure Storage
          → simpan user lokal (+ POST /auth/register jika online)
Login   : input → hash(input + salt) == tersimpan? 
             Ya    → buat token + expiry → Secure Storage → buka DB terenkripsi → SCR-02
             Tidak → "Email atau password salah", hitung percobaan
Logout  : dialog konfirmasi → hapus token → tutup DB → bersihkan state → SCR-01
```

### 3.3 Tambah Buku & Sesi Membaca (WF-05)
```
Tambah: FAB (SCR-03) / hasil pencarian online (SCR-08) → SCR-07 → validasi → simpan SQLite → tandai dirty
Sesi  : Mulai Baca (SCR-02) → SCR-15 → simpan start_timestamp → Selesai & Simpan
        → durasi = now − start_timestamp → update progres, total jam, streak, target
        → target harian tercapai? → notifikasi
        → halaman = total? → dialog "Tandai selesai?" → wajib isi ulasan & rating → WF-08
```

### 3.4 Blockchain (WF-08)
```
Status → Selesai → review_hash = SHA256(ulasan)
→ block {index, timestamp, book_id, review_hash, finished_date, previous_hash}
→ hash = SHA256(semua field) → simpan tabel blocks → notifikasi "Sertifikat diterbitkan"
Validasi: untuk tiap blok hitung ulang hash & cek previous_hash → Valid / Tidak Valid (blok ke-n)
```

### 3.5 AI / LLM (WF-07)
```
Pengguna kirim prompt (+ konteks buku) → POST /ai/chat (token sesi)
→ backend memanggil Gemini (API key di server) → balasan
→ tampil + label "Dihasilkan AI" | error/timeout/kuota → pesan + Coba Lagi | offline → input dinonaktifkan
```

### 3.6 Sensor (WF-06)
```
Accelerometer: magnitudo > ambang, 2 guncangan < 600 ms, lewat debounce 1,5 dtk, layar SCR-02/04, bukan sesi baca/kuis
               → haptic → buku acak dari Wishlist (kosong → rekomendasi AI) → modal
Sensor cahaya: tema = Otomatis? → lux < 15 ≥ 2 dtk → Dark | lux > 40 ≥ 2 dtk → Light
               (iOS: ikuti tema sistem; mode Manual: sensor diabaikan)
```

### 3.7 Sinkronisasi (WF-03)
```
Perubahan lokal → dirty + updated_at → online?
   Ya    → POST /sync → server membalas data terbaru → last-write-wins → tandai synced
   Tidak → tetap di antrean, coba lagi saat koneksi kembali
```

### 3.8 Notifikasi (WF-06)
```
Atur jam di Profil → jadwalkan pengingat harian lokal (timezone-aware)
Event (target tercapai / streak / sertifikat) → tampilkan notifikasi sistem + simpan ke tabel notifications
Ketuk notifikasi → buka layar terkait (SCR-06 / SCR-15 / SCR-14)
```

---

## 4. Standar Teknis Pengerjaan

### 4.1 Git
- Cabang: `main` (stabil), `develop`, `feature/wf-0X-nama`.
- Commit: `feat(wf-02): login biometrik`, `fix(wf-05): filter rating`, `docs: ...`.
- Merge ke `develop` setelah Definition of Done; `main` hanya untuk build tiap minggu presentasi.

### 4.2 Struktur Folder (disarankan)
```
storyloka/
  lib/
    main.dart
    app/                 -> router, tema, dependency injection
    core/
      theme/             -> token warna, tipografi, spacing (dokumen desain Bagian 1)
      widgets/           -> StorylokaCard, BottomNavBar, StatusBadge, tombol, state loading/kosong/error
      db/ network/ security/ utils/
    features/
      auth/ home/ library/ book_detail/ search/ reading_session/
      ai/ explore/ (map, converter, game)/ profile/ feedback/ notifications/ blockchain/
  backend/               -> REST API (Node.js/Express)
  docs/                  -> dokumen ini + screenshot + diagram
```

### 4.3 Keamanan
- Dilarang menyimpan password polos, API key, atau token di kode atau SharedPreferences biasa.
- Semua panggilan jaringan via HTTPS; validasi input di klien dan server; jangan mencatat data sensitif ke log.

### 4.4 Izin Platform
| Fitur | Android | iOS |
|---|---|---|
| Lokasi (LBS) | `ACCESS_FINE_LOCATION` | `NSLocationWhenInUseUsageDescription` |
| Biometrik | `USE_BIOMETRIC` | `NSFaceIDUsageDescription` |
| Notifikasi | `POST_NOTIFICATIONS` (Android 13+) | Izin runtime |
| Kamera / galeri | `CAMERA`, akses media | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` |
| Internet | `INTERNET` | – |

### 4.5 Pembagian Tugas (isi sesuai anggota)
| Anggota | Modul tanggung jawab |
|---|---|
| (isi) | (mis. WF-01, 02, 04: auth & navigasi & UI) |
| (isi) | (mis. WF-03, 05, 07: data, library, backend, AI) |
| (isi) | (mis. WF-06, 08, 09, 10, 11: sensor, blockchain, game, testing, laporan) |

---

## 5. Definition of Done (per Modul)

- [ ] Fitur sesuai spesifikasi di `deskripsi_proyek.md` Bagian 5.
- [ ] Tampilan sesuai spesifikasi layar SCR-xx dan checklist di `referensi_desain_ui_ux.md`.
- [ ] State kosong, loading, error/offline tertangani; Light dan Dark Mode tampil benar.
- [ ] Test case modul (Bagian 6) dijalankan dan lulus.
- [ ] Screenshot layar (Light & Dark) diambil untuk laporan.
- [ ] Kode berkomentar pada logika penting (bahan penjelasan source code laporan).
- [ ] Digabung ke `develop` tanpa error `flutter analyze`.

---

## 6. Rencana Pengujian (Black-box): Bahan Lembar Evaluasi

| ID | Modul | Skenario | Langkah singkat | Hasil diharapkan | Status |
|---|---|---|---|---|---|
| TC-01 | WF-02 | Register valid | Isi data benar → Daftar | Akun dibuat, masuk SCR-02 | ☑ |
| TC-02 | WF-02 | Password < 8 karakter | Daftar dengan password pendek | Ditolak, pesan validasi | ☑ |
| TC-03 | WF-02 | Login password salah | Isi password salah | Pesan umum, tidak masuk | ☑ |
| TC-04 | WF-02 | Password tersimpan ter-hash | Periksa isi DB | Tidak ada teks polos | ☑ |
| TC-05 | WF-02 | Sesi kedaluwarsa | Ubah expiry → buka app | Dialog sesi berakhir → login | ☑ |
| TC-06 | WF-02 | Biometrik berhasil | Aktifkan di Profil → buka ulang app | Verifikasi → SCR-02 | ☑ |
| TC-07 | WF-02 | Biometrik gagal 3× | Gagal 3× | Form password | ☑ |
| TC-08 | WF-02 | Logout | Slot Logout → Keluar | Token terhapus, ke SCR-01 | ☑ |
| TC-09 | WF-04 | Bottom nav | Ketuk 5 slot | Beranda/Explore/Profil/Kesan sesuai; Logout memunculkan dialog | ☑ |
| TC-10 | WF-04 | Ganti foto profil | Kamera/galeri → Simpan | Foto tampil di Profil & Beranda | ☑ |
| TC-11 | WF-04 | Kesan & saran | Isi → Simpan | Tersimpan lokal dan terkirim | ☑ |
| TC-12 | WF-05 | Tambah buku | Isi form → Simpan | Muncul di Koleksi | ☑ |
| TC-13 | WF-05 | Pilih hasil pencarian online | Cari → Pilih | Form terisi otomatis | ☑ |
| TC-14 | WF-05 | Filter | Genre + rating ≥ 4 + tahun | Hanya hasil sesuai | ☑ |
| TC-15 | WF-05 | Sesi baca di latar belakang | Mulai → ke home HP 2 menit → kembali | Durasi akurat ±1 dtk | ☑ |
| TC-16 | WF-05 | Update halaman = total | Simpan sesi | Dialog selesai → ulasan wajib | ☑ |
| TC-17 | WF-05 | Konversi kurs | 100 USD → IDR | Hasil = 100 × kurs; ada waktu pembaruan | ☑ |
| TC-18 | WF-05 | Konversi waktu | 14:00 WIB | WITA 15:00, WIT 16:00, London sesuai DST | ☑ |
| TC-19 | WF-06 | Shake | Kocok HP di Beranda | Buku acak Wishlist + haptic | ☑ |
| TC-20 | WF-06 | Shake tidak salah picu | Diam / berjalan biasa | Tidak muncul modal | ☑ |
| TC-21 | WF-06 | Auto-theme | Tutup sensor cahaya (Android) | Dark Mode setelah ≥ 2 dtk | ☑ |
| TC-22 | WF-06 | LBS izin ditolak | Tolak izin lokasi | Kartu ajakan + Buka Pengaturan | ☑ |
| TC-23 | WF-06 | Notifikasi pengingat | Set jam +1 menit | Notifikasi muncul, tercatat di SCR-14 | ☑ |
| TC-24 | WF-07 | Ringkasan AI | Ringkas dengan AI | Ringkasan + label “Dihasilkan AI” | ☑ |
| TC-25 | WF-07 | AI offline | Matikan internet | Input dinonaktifkan / pesan + Coba Lagi | ☑ |
| TC-26 | WF-08 | Blok baru | Tandai buku selesai | Blok dibuat, validasi Valid | ☑ |
| TC-27 | WF-08 | Tamper | Ubah data blok manual | Validasi Tidak Valid (menunjuk blok) | ☑ |
| TC-28 | WF-09 | Kuis | Selesaikan 10 soal | Skor & koin tersimpan | ☑ |
| TC-29 | WF-03 | Offline lalu sinkron | Tambah buku offline → online | Data terkirim ke server | ☑ |

**Performance testing:** waktu start aplikasi, waktu muat 200 buku, waktu respons AI, pemakaian memori (catat di tabel laporan).

> **Status TC (WF-10, 2026-10-17):** seluruh TC-01…TC-29 **lulus lewat test otomatis** (`flutter test` 88 test; nama test memuat ID TC). TC yang membutuhkan sensor/perangkat (TC-06/07 biometrik, TC-19/20 shake, TC-21 sensor cahaya, TC-22 izin GPS, TC-23 notifikasi, TC-15 latar belakang) diverifikasi lewat abstraksi/seam yang disimulasikan di test; **verifikasi manual di HP Realme C2** dilakukan saat demo akhir.
>
> **Angka performance (host Windows — `test/performance_test.dart`):** PBKDF2 hash+verify 210k ≈ 11,9 dtk · insert 1 buku 95 ms · query 200 buku 45 ms · filter genre 6 ms · buildRound 56 ms · splash → Beranda 6,9 dtk. **Di HP (diukur manual):** waktu start, respons AI, pemakaian memori — diisi saat demo.

---

## 7. Persiapan Laporan & Presentasi (WF-11)

| Bagian laporan | Ambil dari |
|---|---|
| Landasan teori | Riset sesuai teknologi di `deskripsi_proyek.md` Bagian 3 |
| Perancangan | Use Case, ERD, Class Diagram (buat), Flow (Bagian 3 file ini), wireframe (`referensi_desain_ui_ux.md`) |
| Implementasi | Kode + screenshot SCR-01 s.d. SCR-17 |
| Evaluasi | Tabel Bagian 6 yang sudah terisi |

**Checklist presentasi:** demo alur lengkap (login biometrik → tambah buku → sesi baca → selesai + ulasan → blockchain → AI → shake → LBS → konverter → kuis → kesan → logout), video demo cadangan, APK/IPA siap, laporan tercetak + halaman pengesahan sebelum UAS.

---

## 8. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Sensor cahaya tidak ada di iOS | Fallback tema sistem; atau gunakan gyroscope sebagai sensor ke-2 |
| Kuota/limit Gemini | Cache ringkasan, pesan batas kuota yang jelas |
| API kurs/peta/buku gagal | Cache terakhir + label “data lama” |
| Waktu mepet | Utamakan fitur wajib; fitur [Opsional] (barcode, lampiran AI) belakangan |
| Konflik kode antar anggota | Cabang per modul, review sebelum merge |
| Stopwatch tidak akurat di latar belakang | Hitung dari timestamp, bukan penghitung per detik |

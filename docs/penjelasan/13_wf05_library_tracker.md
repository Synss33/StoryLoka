# WF-05 — Library, Reading Tracker, Pencarian & Konverter

> **Fitur:** F-19 (reading tracker inti), F-10 (pencarian & pemilihan), F-17 (konversi mata uang), F-18 (konversi waktu), F-04 form buku, F-20 (scan barcode ISBN, opsional) · **Layar:** SCR-02, SCR-03, SCR-07, SCR-08, SCR-15 (+ kerangka SCR-06) · **Alur:** workflow §3.3 · **Test:** TC-12…TC-18, TC-30 (`library_flow_test`, `converter_test`, `isbn_test`)

## 1. Alur tambah buku & sesi membaca (workflow §3.3 → kode)

```
Tambah: FAB SCR-03 / hasil pencarian online SCR-08 → SCR-07 → validasi
      → simpan SQLite + dirty=1
      (F-20, opsional) kartu "Pindai Barcode ISBN" → /scan-isbn → checksum
        → lookup 'isbn:…' → isi field kosong; offline → ISBN + isi manual
Sesi  : Mulai Baca SCR-02 → SCR-15 → simpan start_timestamp
      → Selesai & Simpan → durasi = now − start_timestamp (timestamp, bukan
        penghitung/detik — ketentuan dosen) → update progres, total jam,
        streak, target → target tercapai? → notifikasi (WF-06)
      → halaman = total? → dialog "Tandai selesai?" → wajib ulasan & rating
        → (WF-08: blok hash chain + sertifikat)
```

## 2. Library & Pencarian

**`library_screen.dart:19`** — *"Segmented Koleksi/Wishlist, pencarian singkat, bottom sheet Filter & Sort, grid/list 2 kolom, long-press action sheet (Edit / Pindahkan / Hapus), dan FAB Tambah Buku (satu-satunya FAB — Bagian 2, Zona 3)."* `:405` state kosong SCR-12 per tab/hasil.

| File | Komentar penting |
|---|---|
| `library_data.dart:21` | tab: buku `wishlist` hanya di tab Wishlist, sisanya Koleksi (desain Bagian 7); `:32` model filter; `:124` pemetaan filter → `libraryBooksProvider` |
| `filter_sheet.dart:11` | bottom sheet Filter & Sort SCR-08: Genre, Status, Rating, Tahun, Urutkan, Reset; batal = filter lama |
| `add_book_screen.dart:21` | SCR-07: judul* & halaman* wajib (halaman ≥ 1); prefill hasil online (TC-13); sampul kamera/galeri (reuse `PhotoPicker`); `:137` `_scanIsbn` (F-20) → checksum → lookup `isbn:` → isi field kosong (TC-30); `:127` simpan → insert/update → dirty (TC-12) |
| `isbn_scanner.dart:5` | abstraksi `IsbnScanner` + `isbnScannerProvider` (pola `PhotoPicker`) — test TC-30 menyuntikkan hasil pindaian tanpa kamera |
| `scan_isbn_screen.dart:8` | layar `/scan-isbn`: `MobileScanner` + viewfinder overlay, deteksi sekali → `pop(barcode)`; izin ditolak / batal → `null` |
| `search_screen.dart:18` | SCR-08: tab **Koleksi Saya** (lokal, offline) + tab **Cari Online** dengan aksi `Pilih` (TC-13), `+ Wishlist`, `+ Koleksi` |
| `search_data.dart:10` | kata kunci online dipisah dari filter lokal — *"pencarian online hanya berjalan saat pengguna menekan tombol cari (hemat kuota API publik)"*; `:32` simpan hasil online langsung |
| `core/network/book_search_service.dart:36` | *"Dua sumber dipanggil berurutan (Google Books → Open Library); kegagalan satu sumber diabaikan selama sumber lain memberi hasil; interface abstraksi agar TC-13 dapat menyuntikkan data palsu"* |

## 3. Beranda (SCR-02)

**`home_screen.dart:24`** — *"Header sapaan + lonceng + avatar; Reading Summary (`primary-500`); kartu Currently Reading dengan tombol Mulai Baca → SCR-15; Aksi Cepat; carousel My Collection → SCR-03."* `:370` titik merah lonceng = notifikasi belum dibaca; `:422` pantau status `GET /health` + buka DB (DoD WF-01).

`home_data.dart:10` — satu async provider: ringkasan baca + Currently Reading (+progres halaman) + carousel.

**Statistik** — `core/utils/reading_stats.dart:6`: *"streak = jumlah hari berturut-turut (termasuk hari ini atau kemarin) yang punya sesi baca"*; `:114` hitung mundur — streak tidak langsung putus sebelum tengah malam; `[now]` disuntik untuk test.

## 4. Sesi membaca (SCR-15) — stopwatch timestamp

**`session_timer.dart:1`** — *"Durasi dihitung dari selisih waktu nyata (`now − start_ts − jeda`), **bukan penghitung per detik** — sehingga tetap akurat saat aplikasi berpindah ke latar belakang (TC-15, ketentuan dosen)."*

- `:20`/`:26` jeda & lanjut (akumulasi jeda); `:41` `durationSec` saat disimpan (akurat ±1 dtk); `:44` format `HH:MM:SS` angka stopwatch.
- `reading_session_screen.dart:36` — simpan sesi → `reading_sessions` + perbarui buku; **halaman tembus total → dialog tandai selesai dengan ulasan wajib** (TC-16).

**Selesai + ulasan** — `book_detail/completion.dart:19` — *"dialog konfirmasi → wajib ulasan & rating → status `completed` + `finished_at` → tabel `reviews` → **blok hash chain** (WF-08) + notifikasi 'Sertifikat diterbitkan'"*; `:67` batal = buku tidak ditandai selesai.

## 5. Konverter (SCR-04)

**Mata uang (F-17)** — `converter_panel.dart:16`: *"Kurs dari `GET /rates` (backend) dan di-cache di SQLite `rate_cache` untuk pemakaian offline; label 'diperbarui …' memakai `fetchedAt`."*
- `core/utils/currency.dart:1` — IDR/USD/EUR/JPY; `rate_to_idr` = berapa IDR per 1 unit (sama dengan balasan server & kolom cache); `:60` konversi; `:75` format Indonesia (`16.300,50`).
- `core/network/rates_service.dart:18` — *"bila server tak terjangkau, jatuh ke cache; `null` bila keduanya kosong."*

**Waktu (F-18)** — `converter_panel.dart:199` — WIB/WITA/WIT/London (konteks: jadwal book club, rilis global).
- `core/utils/world_clock.dart:1` — *"murni Dart tanpa paket tambahan agar dapat diuji di host (TC-18) dan bekerja offline. DST London: aktif Minggu terakhir Maret 01:00 UTC → Minggu terakhir Oktober 01:00 UTC."* `:70` `"HH:mm"` 24 jam; `:77` tanggal Indonesia.

## 6. API yang dipakai

| Endpoint / layanan | Pemanggil |
|---|---|
| `GET /rates` (backend) | `rates_service.dart:30` → cache `rate_cache` |
| Google Books / Open Library | `book_search_service.dart:68/:137` (langsung, tanpa key) |
| `GET /health` (pantauan) | `home_screen.dart:422` |

## 7. Test & keputusan

- **TC-12…TC-16** `library_flow_test` (tambah, prefill online, filter, stopwatch timestamp, sesi→selesai+ulasan wajib) · **TC-17/18** `converter_test` (kurs + UI panel, zona waktu + DST).
- Keputusan: **K-28** (kurs lewat backend + cache), **K-29** (bottom sheet `useRootNavigator`), **K-30** (`SessionTimer` timestamp), **K-31** (tinggi carousel 300 dp — fix overflow TC-16), **K-11** (stopwatch timestamp).

# WF-04 — Navigasi (Bottom Nav), Profil & Kesan-Saran

> **Fitur:** F-06 (bottom navigation), F-07 (menu profil berfoto), F-08 (saran & kesan PAM) · **Layar:** SCR-09, SCR-10, SCR-17 + Master Layout seluruh aplikasi · **Test:** TC-09…TC-11 (`widget_test`, `edit_profile_test`, `feedback_flow_test`, `profile_test`)

## 1. Navigasi & Master Layout (fondasi visual)

**`lib/app/shell.dart:9`** — *"Zona 4 Master Layout: wadah 4 tab (Beranda, Explore, Profil, Kesan) + slot Logout. Bottom nav tampil untuk rute di dalam shell (SCR-02, 03, 04, 09, 10, 14); layar fokus dideklarasikan di luar shell sehingga nav otomatis disembunyikan."*

**`lib/core/widgets/bottom_nav_bar.dart:7`** — *"Slot: **Beranda · Explore · Profil · Kesan · Logout**. Indikator aktif: ikon + label `primary-500` dan pil `primary-50` (hanya 4 tab; slot Logout **bukan layar**, selalu `danger-500` dan hanya membuka dialog konfirmasi)."*

**`lib/app/router.dart:26`** — 4 cabang `StatefulShellRoute.indexedStack` → nav tampil; rute luar shell (`/ai`, `/book/:id`, `/search`, `/session`, `/game`, `/profile/edit`, …) → nav disembunyikan (Bagian 3.3). Peta rute lengkap: [`02_arsitektur_alur.md`](02_arsitektur_alur.md) §3.

**Dialog Logout (F-09)** — `shell.dart:36`: *"Aksi Keluar: kembali ke SCR-01, hapus token sesi, tutup database terenkripsi… Data buku lokal tetap tersimpan (terenkripsi)."*

**Komponen Master Layout** (`lib/core/widgets/`, dipakai semua layar):

| Widget | Komentar penting |
|---|---|
| `top_bar.dart:5` | Zona 1: 56 dp, sticky, **maks 2 ikon aksi**; `:24` konten awal tambahan (avatar Beranda) |
| `storyloka_card.dart:6` | Kartu dasar: `surface`, radius 12, padding 16; terang = bayangan, gelap = border `neutral-200`; *"semua kelompok data wajib dibungkus widget ini (Zona 2)"* |
| `buttons.dart:5` | Tinggi 48 dp, radius 12; state loading = spinner + nonaktif (Bagian 1.4) |
| `loading_skeleton.dart:6` | SCR-11 shimmer 1,2 dtk; cover rasio 2:3, teks 70%/40% |
| `empty_state.dart:8` / `error_state.dart:8` | SCR-12 (ilustrasi + judul + CTA) / SCR-13 (ikon `danger-500`, "Koneksi Terputus", Coba Lagi) |
| `book_cover.dart:8`, `status_badge.dart:8`, `profile_avatar.dart:7` | Sampul 2:3 radius 8 · badge warna per status · foto-or-inisial (TC-10) |

## 2. Profil (SCR-09) & Edit (SCR-17)

**`profile_screen.dart:20`** — *"Header berfoto → SCR-17; statistik ringkas; keamanan & sesi; notifikasi; tema (auto/terang/gelap) yang dipersistensi; sinkronisasi manual. **Tidak ada tombol Logout di sini** — logout ada di bottom nav."*

| File | Komentar penting |
|---|---|
| `profile_data.dart:12` | Satu async provider SCR-09; aksi pengaturan cukup `invalidate(profileDataProvider)`; `:32` perangkat tanpa biometrik → opsi disembunyikan |
| `profile_stats.dart:7` | "28 Buku · 96 Jam · 5 Sertifikat · 120🪙" — semuanya dihitung dari tabel lokal; `:23` jumlah blok hash; `:26` total koin game (WF-09) |
| `profile_screen.dart:67` | Level Pembaca dari jumlah buku selesai: Pemula <10 · Rutin 10–49 · Kutu Buku ≥50 (K-26) |
| `edit_profile_screen.dart:16` | SCR-17: ganti foto, ubah nama, ganti password **dengan verifikasi password lama** |
| `photo_service.dart:8` | Antarmuka `PhotoPicker` → test menyuntikkan pemilih palsu (K-23); `:39` foto disalin ke direktori dokumen sebagai `profile_photo.<ext>` agar path stabil |

## 3. Kesan & Saran PAM (SCR-10, F-08)

**`feedback_screen.dart:16`** — *"Dua kolom isian; isian terakhir tampil ulang dan dapat diedit. Simpan selalu ke tabel lokal (`synced = 0`), lalu dikirim ke `POST /feedback` — bila gagal (offline), antrean dikirim lewat `/sync`."*

- Simpan = `FeedbackRepository.save` (upsert per `user_id`, K-25) → antrean `synced = 0`.
- `POST /feedback` best-effort; `GET /feedback` **hanya bila data lokal kosong** (K-27) — `feedback_screen.dart:58`.
- Server: `feedback.controller.js:15` — validasi minimal satu kolom, LWW per pengguna.

## 4. API yang dipakai

| Endpoint | Pemanggil | Sifat |
|---|---|---|
| `POST /feedback` | `feedback_screen.dart:126` | best-effort → gagal masuk antrean `/sync` |
| `GET /feedback` | `feedback_screen.dart:58` | hanya bila lokal kosong |

## 5. Test & keputusan

- **TC-09** `widget_test` (5 slot, dialog Logout, pindah tab, layar fokus tanpa nav) · **TC-10** `edit_profile_test` (foto tampil di SCR-17/SCR-09/Beranda) · **TC-11** `feedback_flow_test` (simpan → terkirim + validasi) · `profile_test` (update profil, email ganda, ganti password, tema).
- Keputusan: **K-9** (go_router shell), **K-23** (abstraksi photo), **K-24** (skema v3 `streak_notify`), **K-25** (feedback 1 baris/pengguna), **K-26** (level pembaca), **K-27** (feedback lokal-first), **K-29** (`useRootNavigator` untuk bottom sheet — bug TC-14).

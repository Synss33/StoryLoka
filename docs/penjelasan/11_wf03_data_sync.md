# WF-03 — Data Lokal (SQLite) & Sinkronisasi Dua Arah

> **Fitur:** F-04 (DB lokal), F-05 (DB online/web service) · **Layar:** semua · **Alur:** workflow §3.7 · **Test:** `db_test`, `book_repository_test`, TC-29 (`sync_test`)

## 1. Arsitektur data

**Skema** — `lib/core/db/schema.dart:3`: *"Waktu disimpan sebagai INTEGER **epoch millisecond (UTC)** agar mudah dibandingkan untuk aturan last-write-wins dan hitung durasi sesi; Boolean sebagai 0/1; `dirty` (1 = belum tersinkron) dan `deleted` (soft delete) disediakan untuk antrean sinkronisasi."*

Versi skema (`schema.dart:12`): v1 pembuatan → v2 `settings.updated_at` (LWW, WF-03) → v3 `settings.streak_notify` (WF-04) → v4 tabel `ai_cache` (WF-07). *"Setiap perubahan wajib menaikkan nomor + menulis onUpgrade"* (`:210`).

12 tabel lokal sesuai `deskripsi_proyek.md` Bagian 5.2 (users, books, reading_sessions, notes_quotes, reviews, blocks, feedback, settings, game_scores, notifications, rate_cache, ai_cache).

**Pembuka DB** — `app_database.dart:5`: produksi SQLCipher dengan kunci dari `DbKeyStore`; *"unit test di host: pabrik (`databaseFactoryFfi`) boleh disuntikkan"* (K-7). `database_provider.dart:10`: bila platform tidak mendukung → provider gagal diam-diam → `null` (logika bisnis tidak ada di provider).

**Model** — `lib/core/models/` (9 file): murni `toRow`/`fromRow` tanpa dependensi plugin; payload `POST /sync` = nama kolom (`book.dart:72`).

## 2. Aturan konflik (deskripsi Bagian 5.2 → kode)

| Kelompok tabel | Aturan | Lokasi kode |
|---|---|---|
| books, sessions, feedback, settings | ***last-write-wins*** berdasarkan `updated_at` | tiap `applyServer` repository + `sync.store.js:61` |
| notes, reviews, blocks (append-only) | ***insert-if-absent*** (idempoten) | `note_quote_repository.dart:47`, `review_repository.dart:34`, `block_repository.dart:77`, `sync.store.js:75` |

## 3. Alur sinkronisasi (workflow §3.7 → kode)

`lib/core/network/sync_service.dart:25`:
```
perubahan lokal → dirty + updated_at → online?
ya    → POST /sync → server balas snapshot → last-write-wins → tandai synced
tidak → tetap antrean, dicoba lagi dengan backoff (coba saat koneksi kembali)
```

| Langkah | Metode (`sync_service.dart`) |
|---|---|
| Ada antrean? (`dirty`/`synced=0`) | `hasPending()` `:57` |
| Kirim satu putaran | `syncOnce()` `:69` |
| Jalankan + backoff 5→15→60→300 dtk | `kick()` `:133` |
| Terapkan balasan LWW + `last_sync` | `_applySnapshot()` `:173` |
| Batalkan jadwal (logout/DB tutup) | `cancel()` `:236` |

`BookRepository` menandai sinkronisasi: setiap tulis → `dirty = 1` + `updated_at = now` (`book_repository.dart:7`); `pendingSync()` `:172`; `applyServer` `:182` *"bila `updated_at` server lebih baru, baris lokal diganti; bila lebih lama, lokal menang (LWW)"*; `markSynced` `:210`.

**Deteksi kembali online tanpa paket connectivity** (K-22): `kick()` dipanggil splash masuk Beranda + setelah aksi tulis; gagal → antrean dijaga backoff.

## 4. File kunci & komentar penjelas (`///`)

| File | Komentar penting |
|---|---|
| `core/db/schema.dart` | `:3` konvensi epoch-ms/0-1/dirty/deleted; `:12` daftar versi v1–v4 |
| `core/db/book_repository.dart` | `:7` aturan dirty/sync/soft-delete; `:42` `list()` mendukung `query`/`genre`/`minRating`/`year`/`orderBy` (SCR-08, TC-14); `:162` "hapus lunak — data tetap tersimpan terenkripsi (Bagian 5.1 logout)" |
| `core/db/reading_session_repository.dart` | `:7` append-only + LWW; `:49` halaman terakhir terjauh = dasar progres % (buku tidak punya kolom halaman); `:60` total durasi = "total jam" SCR-06 |
| `core/db/note_quote_repository.dart` | `:7` insert-if-absent; `:47` snapshot server idempoten |
| `core/db/review_repository.dart` | `:7` append-only — ulasan dibuat sekali saat selesai (WF-05) dan dipakai blockchain (WF-08) |
| `core/db/feedback_repository.dart` | `:25` upsert per pengguna — isian terakhir menimpa yang lama (SCR-10); `:60` antrean `synced = 0` |
| `core/db/settings_repository.dart` | `:7` kolom per modul (biometric WF-02, last_sync WF-03, tema WF-04, pengingat WF-06, target WF-05); `:109` target 1…100 |
| `core/network/api_client.dart` | `:14` base URL via `--dart-define` (bukan hard-coded); `:67` `tryPostJson` tanpa menunggu hasil (panggilan best-effort); `:93` `postJson` dengan hasil (sinkronisasi); `:128` `tryGetJson`; `:93` status `-1` = offline |

**Backend:** `controllers/sync.controller.js:17` kontrak request/response; `services/sync.store.js:5` struktur JSON per pengguna + aturan konflik + *"bila butuh skala besar, ganti dengan basis data relasional tanpa mengubah kontrak API"*.

## 5. Test & keputusan

- `db_test` (skema/migrasi), `book_repository_test` (CRUD + dirty + LWW), **TC-29** `sync_test` (offline → antrean → online terkirim; LWW dua arah; tanpa sesi tidak mengirim; kick backoff).
- Keputusan: **K-19** (letak model/repository), **K-20** (migrasi v2), **K-21** (kontrak snapshot penuh + ID lokal = satu perangkat), **K-22** (kick + backoff), **K-7/K-16** (ffi untuk test).

# WF-08 — Blockchain Sederhana: Proof of Reading (F-12)

> **Fitur:** F-12 (hash chain SHA-256) · **Layar:** SCR-06 (kartu blockchain + sertifikat), SCR-14 (notifikasi) · **Alur:** workflow §3.4 · **Test:** TC-26, TC-27 (`blockchain_test`)

> **Catatan:** blockchain di sini = **hash chain SHA-256 lokal**, bukan kripto/NFT (ketentuan dosen).

## 1. Rumus (workflow §3.4 → `hash_chain.dart:17`)

```text
review_hash = SHA256(teks ulasan)
block       = { index, timestamp, book_id, review_hash,
                finished_date, previous_hash }
hash        = SHA256(index | timestamp | book_id | review_hash |
                     finished_date | previous_hash)
```
Blok pertama per pengguna memakai `genesisPreviousHash` = **64 karakter nol** (`hash_chain.dart:29`, deskripsi Bagian 5.7).

**Validasi** (`hash_chain.dart:81`): *"untuk tiap blok, cocokkan `previous_hash` dengan blok sebelumnya **dan** hitung ulang `hash`-nya. Hasil: `Valid`, atau `Tidak Valid` yang menunjuk nomor blok rusak. Rantai kosong dianggap valid."*

## 2. Pemicu pembuatan blok (K-43)

`features/book_detail/completion.dart:19` — hook di dialog ulasan:
```
dialog konfirmasi → wajib ulasan & rating → status completed + finished_at
→ tabel reviews → blok hash chain berikutnya (idx = max+1 per pengguna,
  previous_hash = hash blok terakhir / genesis) → notifikasi "Sertifikat diterbitkan"
```
Satu buku selesai = satu blok; `timestamp`/`finished_date` = epoch ms yang sama.

## 3. File kunci & komentar penjelas (`///`)

| File | Komentar penting |
|---|---|
| `core/blockchain/hash_chain.dart:17` | definisi hash chain "Proof of Reading" (bukan kripto/NFT) + rumus; `:33` `sha256Hex` = heksadesimal lowercase 64 karakter (paket `crypto`, **K-42** — sinkron); `:45` `buildBlock`; `:110` potongan tampilan `8f4a…e91c` |
| `core/db/block_repository.dart:7` | *"Append-only dengan PK `(user_id, idx)`; server menyimpan salinan sebagai **anchor** pembanding rantai"*; `:49` `lastByUser` = dasar `previous_hash`; `:63` blok milik buku (sertifikat SCR-06); `:77` snapshot server idempoten |
| `core/models/block.dart:1` | PK gabungan `(user_id, idx)`; `hash` = SHA-256 seluruh isi blok |
| `features/blockchain/blockchain_card.dart:20` | kartu 🛡 di SCR-06 — hanya buku *Selesai*: badge `success-500`, nomor blok, hash terpotong, `previous_hash`, tanggal, tombol **Validasi Rantai** + **Bagikan Sertifikat**; `:46` validasi = ambil **seluruh** blok pengguna → hitung ulang → Valid / Tidak Valid (blok ke-n); `:64` tangkap pratinjau → PNG → menu berbagi **sebelum dialog ditutup**; `:105` `RepaintBoundary.toImage` pixelRatio 2.5 |
| `features/blockchain/reading_certificate.dart:10` | kartu sertifikat "Proof of Reading" — dilukis penuh agar `toImage` bisa menangkap; `:24` key `RepaintBoundary` disuntikkan dari `BlockchainCard` |
| `features/blockchain/certificate_share_service.dart:6` | *"Dibungkus abstraksi agar pengujian dapat menyuntikkan tiruan tanpa memanggil platform share (seam sama dengan `NotificationService`/`PhotoPicker`)"*; `:14` implementasi `share_plus` (K-44) |

**Notifikasi sertifikat (K-45):** `NotificationCoordinator.emitEvent(type: certificate, dedupePerDay: false)` dengan rute `/book/<id>` → ketuk membuka SCR-06; satu kali per blok (tidak di-dedupe per hari).

## 4. API yang dipakai

Tidak ada endpoint baru. Blok dikirim sebagai bagian **`POST /sync`** (field `blocks[]`, append-only `insert-if-absent` — `sync.controller.js`, `sync.store.js:75`) sebagai *anchor* pembanding rantai di server.

## 5. Test & keputusan

- **TC-26** `blockchain_test` — tandai selesai → blok dibuat + notifikasi + Validasi = **Valid**.
- **TC-27** `blockchain_test` — ubah data blok manual → **Tidak Valid** (menunjuk blok ke-0).
- Unit `HashChain` (buildBlock/validate/genesis) + 1 test pratinjau sertifikat.
- Keputusan: **K-42** (`crypto` sinkron, bukan `cryptography`), **K-43** (hook di dialog ulasan), **K-44** (tangkap PNG dari dialog pratinjau + abstraksi share), **K-45** (notifikasi sertifikat tanpa dedupe harian).

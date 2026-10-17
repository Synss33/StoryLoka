# Penggunaan API & Backend — Penjelasan untuk Laporan

> Sumber: `backend/src/app.js`, `backend/src/routes/*`, `backend/src/controllers/*`,
> `lib/core/network/*`, `lib/features/auth/auth_controller.dart`,
> `docs/deskripsi_proyek.md` Bagian 5.2, `docs/keputusan.md` K-4/14/21/36.

## 1. Gambaran umum

Aplikasi berkomunikasi dengan **REST API sendiri** (Node.js + Express 5) —
**tanpa Firebase** (ketentuan dosen). Pola umumnya:

1. Base URL diatur saat build, **bukan hard-coded**:
   `--dart-define=API_BASE_URL=http://<ip>:3000`
   (bawaan `http://10.0.2.2:3000` = loopback emulator Android) — `lib/core/network/api_client.dart:31`, K-4.
2. Semua panggilan memakai `ApiClient` (timeout **8 detik**, `api_client.dart:39`).
3. Endpoint (kecuali `POST /auth/register` & `POST /auth/login`) memerlukan header
   **`Authorization: Bearer <token sesi>`** — diverifikasi middleware
   `requireAuth` (`backend/src/middleware/auth.js`).
4. Klien bersifat **offline-first / best-effort**: kegagalan jaringan tidak
   memblokir alur utama — data lokal (SQLite) tetap sumber kebenaran (K-17, K-22).

## 2. Daftar endpoint

| # | Method & path | Auth | Handler (`backend/src/…`) | Pemanggil klien (`lib/…`) |
|---|---|---|---|---|
| 1 | `GET /health` | – | `controllers/health.controller.js` | `core/network/api_client.dart:43` `getHealth()` (DoD WF-01) |
| 2 | `POST /auth/register` | – | `controllers/auth.controller.js` `register` | `features/auth/auth_controller.dart:92` (best-effort) |
| 3 | `POST /auth/login` | – | `controllers/auth.controller.js` `login` | `auth_controller.dart:133` (best-effort) |
| 4 | `POST /auth/logout` | Bearer | `auth.controller.js` `logout` | `auth_controller.dart:159` `unawaitedServer` |
| 5 | `POST /sync` | Bearer | `controllers/sync.controller.js` `sync` | `core/network/sync_service.dart:102` |
| 6 | `POST /feedback` | Bearer | `controllers/feedback.controller.js` `postFeedback` | `features/feedback/feedback_screen.dart:126` (best-effort) |
| 7 | `GET /feedback` | Bearer | `feedback.controller.js` `getFeedback` | `feedback_screen.dart:58` (hanya bila lokal kosong, K-27) |
| 8 | `GET /rates` | Bearer | `controllers/rates.controller.js` `getRatesHandler` | `core/network/rates_service.dart:30` |
| 9 | `POST /ai/chat` | Bearer | `controllers/ai.controller.js` `chatHandler` | `core/network/ai_service.dart:50` |
| 10 | `POST /ai/summarize` | Bearer | `ai.controller.js` `summarizeHandler` | `ai_service.dart:69` |
| 11 | `POST /ai/recommend` | Bearer | `ai.controller.js` `recommendHandler` | `ai_service.dart:86` |

Pemetaan rute → middleware ada di `backend/src/app.js:18-43` (komentar daftar endpoint).

### API eksternal (langsung dari klien, tanpa key)

| Endpoint | Fungsi | Kode |
|---|---|---|
| `googleapis.com/books/v1/volumes` | Pencarian buku online (SCR-08) | `core/network/book_search_service.dart:68` |
| `openlibrary.org/search.json` | Pencarian cadangan + cover | `book_search_service.dart:137` |
| `overpass-api.de/api/interpreter` | Titik perpustakaan/toko buku (SCR-04) | `core/network/book_place_service.dart:87` |

## 3. Kontrak tiap endpoint (singkat)

### `GET /health`
Balasan `{ status: "ok", … }` — dipakai splash untuk memastikan backend terhubung.

### `POST /auth/register` · `POST /auth/login` (K-14, K-17)
- Register body: `{ name, email, password }` (validasi server: email pola, password ≥ 8) → balas **201** `{ token, expiresAt, user }`.
- Login body: `{ email, password }` → hash ulang dengan **PBKDF2 `node:crypto` + salt** lalu bandingkan → balas `{ token, expiresAt, user }`.
- Token = acak 32 byte, berlaku 7 hari, disimpan di `backend/data/users.json` (di-gitignore).
- Klien mengirim **best-effort**: offline/gagal diabaikan — akun tetap ada lokal (alur workflow §3.2: *"simpan user lokal (+ POST jika online)"*).

### `POST /sync` (K-21) — inti WF-03
- Request: `{ since, books[], sessions[], notes[], reviews[], blocks[], feedback[], settings }` — hanya baris **`dirty = 1`** (dan seluruh baris append-only).
- Response: **snapshot penuh** per pengguna + `serverTime`.
- Server (`services/sync.store.js`): tabel bervariabel waktu → ***last-write-wins* `updated_at`**; append-only (notes/reviews/blocks) → ***insert-if-absent***.
- ID lokal autoincrement dipertahankan → asumsi satu perangkat utama per pengguna.

### `POST /feedback` · `GET /feedback` (K-25, K-27)
- Body `{ kesan?, saran?, updated_at? }`; **minimal satu kolom** terisi (validasi server `postFeedback`).
- Satu baris per pengguna (upsert by `user_id`); `GET` hanya saat data lokal kosong.

### `GET /rates` (K-28)
- Balasan `{ rates: { USD, EUR, JPY }, fetchedAt, serverTime }` — `rates` = **IDR per 1 unit** (sama dengan kolom `rate_cache` klien).
- Server menarik `open.er-api.com/v6/latest/IDR`, cache TTL 6 jam, mode `RATES_OFFLINE=1` untuk test; klien menyimpan ke SQLite → tampil "diperbarui <waktu>" & tetap jalan offline.

### `POST /ai/chat|summarize|recommend` (K-36, K-37) — WF-07
- Chat body: `{ message, history?, context? }` (context = konteks buku dari SCR-06, maks 500 char) → balas `{ reply, serverTime }`.
- Backend memanggil **Gemini** (`GEMINI_API_KEY` hanya di `.env`, model `gemini-2.5-flash`, timeout 20 dtk) dengan **prompt sistem**: bahasa Indonesia + hanya seputar buku, maks ±120 kata.
- Galat berkode agar klien memetakan state UI (`services/ai.service.js`):

| Status | `error.code` | Tampilan klien (`AiFailure`) |
|---|---|---|
| 429 | kuota | pesan batas kuota |
| 503 | `AI_DISABLED` | "Layanan AI belum tersedia." |
| 504 | timeout | pesan + **Coba Lagi** |
| – | offline (tanpa jaringan) | input dinonaktifkan + banner (TC-25) |

- `AI_MOCK=1` → balasan tetap tanpa jaringan (test deterministik).

## 4. Alur sinkronisasi dua arah (workflow §3.7)

```
Aksi tulis di app → SQLite: dirty=1 + updated_at=now → antrean lokal
   ├─ online  → POST /sync (baris dirty + append-only + settings)
   │              → server: LWW / insert-if-absent
   │              → balasan snapshot penuh → klien: LWW → tandai synced
   └─ offline → tetap di antrean; kick() ulang saat splash/aksi tulis
                 dengan backoff 5 → 15 → 60 → 300 detik (K-22)
```

Deteksi "kembali online" **tanpa** `connectivity_plus`: `SyncService.kick()`
dipanggil saat splash masuk Beranda (`core/network/sync_service.dart`).

## 5. Keamanan endpoint

- `.env` tidak dikomit; `GEMINI_API_KEY` tidak pernah dicetak/log/dikirim ke klien (K-6, `config/env.js`).
- Validasi input dua sisi (klien & server) + balasan `{ error: { code, message } }` berbahasa Indonesia.
- Batas body 1 MB, JSON only (`app.js`); urutan middleware: 404 → error handler global.
- HTTP `cleartext` hanya selama pengembangan; rilis wajib HTTPS (K-5).

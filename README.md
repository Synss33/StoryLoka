# Storyloka: Personal Book Library & Reading Tracker

> *Temukan, Simpan, & Lacak Bacaanmu*

Tugas Akhir **Pemrograman Aplikasi Mobile**. Aplikasi pencatat perpustakaan dan aktivitas membaca dengan AI/LLM, blockchain sederhana (hash chain), sensor, LBS, konverter mata uang & waktu, mini game, serta login terenkripsi + biometrik (tanpa Firebase).

## 📖 URUTAN MEMBACA (WAJIB untuk manusia maupun AI/asisten kode)

Sebelum mengerjakan, mengubah, atau menjawab pertanyaan apa pun tentang proyek ini, baca **ketiga** dokumen berikut **secara berurutan**:

| # | Dokumen | Menjawab pertanyaan |
|---|---|---|
| 1 | [`docs/deskripsi_proyek.md`](./docs/deskripsi_proyek.md) | **APA** yang dibangun? Ketentuan dosen, fitur F-01…F-20, tech stack, model data, API, struktur laporan |
| 2 | [`docs/referensi_desain_ui_ux.md`](./docs/referensi_desain_ui_ux.md) | **BAGAIMANA tampilannya?** Design tokens, Master Layout, navigasi, wireframe & spesifikasi SCR-01…SCR-17 |
| 3 | [`docs/workflow_proyek.md`](./docs/workflow_proyek.md) | **BAGAIMANA mengerjakannya?** Roadmap WF-01…WF-11, alur sistem, Definition of Done, test case |

Pendukung: [`docs/prototipe_ui_storyloka.html`](./docs/prototipe_ui_storyloka.html), prototipe interaktif 5 layar awal (buka di browser). Sumber gaya visual saja; spesifikasi final ada di dokumen #2.

## 🔗 Aturan Keterkaitan
1. **Setiap fitur (F-xx) punya layar (SCR-xx) dan modul kerja (WF-xx)**; lihat matriks di dokumen #1.
2. **UI apa pun wajib mengikuti dokumen #2** (token, Master Layout, komponen). Jangan membuat gaya baru.
3. **Urutan dan cara kerja mengikuti dokumen #3**; modul dianggap selesai hanya setelah Definition of Done terpenuhi.
4. Jika ada konflik: **Ketentuan Dosen > deskripsi proyek > desain > workflow**.
5. Perubahan yang berdampak ke dokumen lain (mis. layar baru) harus diperbarui di semuanya.

## 🧭 Ringkasan Singkat
- **Bottom nav:** Beranda · Explore · Profil · Kesan · Logout
- **Stack:** Flutter, SQLite terenkripsi (SQLCipher), REST API (Node.js), Gemini via backend, OpenStreetMap
- **Sensor:** Accelerometer (shake) + sensor cahaya (auto-theme; fallback tema sistem di iOS)
- **Konverter:** mata uang IDR/USD/EUR/JPY; waktu WIB/WITA/WIT/London

## 🚀 Cara Menjalankan (Fondasi WF-01)

**Prasyarat:** Flutter SDK (stable), Android SDK, Node.js ≥ 20, HP Android
faktor nyata (USB debugging) atau emulator.

**1. Backend (Node.js/Express):**
```sh
cd backend
npm install
npm run dev          # http://localhost:3000/health
npm test             # test /health & 404 (node --test)
```
Butuh API key Gemini (nanti untuk WF-07)? Salin `.env.example` → `.env`
lalu isi `GEMINI_API_KEY=`. File `.env` tidak boleh dikomit.

**2. Aplikasi Flutter:**
```sh
flutter pub get
flutter analyze
flutter test
# Emulator Android (default API_BASE_URL=http://10.0.2.2:3000):
flutter run
# HP fisik via USB — IP komputer yang menjalankan backend:
flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
```
Status koneksi backend tampil di SCR-02 (Beranda) — bila `Backend terjangkau`
muncul, aplikasi sudah tersambung ke backend.

## 🗂️ Struktur Dokumen
```
README.md                     <- pintu masuk (Anda di sini)
CLAUDE.md                     <- instruksi singkat untuk asisten AI
docs/
  deskripsi_proyek.md         <- spesifikasi & ketentuan
  referensi_desain_ui_ux.md   <- layout & desain
  workflow_proyek.md          <- alur kerja & pengujian
  prototipe_ui_storyloka.html <- prototipe visual
  keputusan.md                <- catatan keputusan teknis
  progress.md                 <- checklist kemajuan WF-01…WF-11 (diperbarui tiap sesi)
backend/                      <- REST API (Node.js/Express), lihat keputusan.md
```

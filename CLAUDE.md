# Instruksi untuk Asisten AI: Proyek Storyloka

Sebelum menulis kode, mengubah dokumen, atau menjawab pertanyaan proyek, **baca berurutan**:

1. `docs/deskripsi_proyek.md`: fitur (F-xx), ketentuan dosen, tech stack, model data, API
2. `docs/referensi_desain_ui_ux.md`: design tokens, Master Layout, navigasi, layar (SCR-xx)
3. `docs/workflow_proyek.md`: modul (WF-xx), alur sistem, Definition of Done, test case
4. `docs/progress.md`: status kemajuan tiap modul (WF-01…WF-11) — **catatan kemajuan saja**, aturan teknis tetap di dokumen 1–3

`docs/prototipe_ui_storyloka.html` hanya referensi gaya visual 5 layar awal; bila berbeda dengan dokumen #2, dokumen #2 yang berlaku.

## Aturan
- Setiap UI WAJIB mengikuti Master Layout, design tokens (indigo/slate, Inter), dan komponen di dokumen desain.
- Bottom nav tetap 5 slot: **Beranda · Explore · Profil · Kesan · Logout**. Logout adalah dialog, bukan layar.
- Setiap fitur dikerjakan sesuai alur dan Definition of Done di dokumen workflow.
- Prioritas jika konflik: Ketentuan Dosen > deskripsi proyek > desain > workflow.
- **Tanpa Firebase.** Password di-hash (Argon2id/PBKDF2 + salt), DB lokal terenkripsi (SQLCipher), kunci/token di secure storage, API key hanya di server.
- Blockchain = hash chain SHA-256 lokal (bukan kripto/NFT).
- Stopwatch dihitung dari timestamp, bukan penghitung per detik.
- Kesan & Saran (SCR-10) adalah untuk **mata kuliah Pemrograman Aplikasi Mobile**, bukan penilaian aplikasi.
- Perubahan yang memengaruhi lebih dari satu dokumen harus diperbarui di semuanya.
- Setiap akhir sesi kerja atau setelah modul selesai, **perbarui `docs/progress.md`** (centang checklist, tandai status, tambah catatan) dan commit bersama hasil kerja.
- Bahasa UI dan dokumentasi: Indonesia.

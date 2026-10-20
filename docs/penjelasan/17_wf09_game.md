# WF-09 — Mini Game: Book Trivia (F-13)

> **Fitur:** F-13 (mini game + koin) · **Layar:** SCR-16 (kuis), SCR-04 (segmen Game), SCR-09 (statistik koin) · **Test:** TC-28 (`game_test`, 10 test)

## 1. Alur fitur

```
SCR-04 segmen "Book Trivia Challenge" (rekor + koin) → Mainkan → /game (layar fokus)
SCR-16: intro (Rekor/Koin) → Mulai Kuis → 10 soal pilihan ganda
  timer 15 dtk/soal (timestamp) → habis = salah (timeout)
  benar → success-500 (+100 poin, +10 koin) | salah/timeout → danger-500 + koreksi
→ Hasil: skor, koin, "Rekor Baru!" → Main Lagi / Kembali
setiap ronde selesai → 1 baris di game_scores → MAX(score) = rekor,
  SUM(coins) = statistik koin SCR-09
```

## 2. File kunci & komentar penjelas (`///`)

### `lib/features/game/question_bank.dart`
| Lokasi | Komentar |
|---|---|
| `:26` | *"Bank soal lokal Book Trivia (deskripsi Bagian 5.8 — soal bawaan offline). Materi: tebak penulis, judul, dan genre buku populer (sastra Indonesia & dunia) agar tetap relevan dengan tema aplikasi membaca."* |
| `:270–279` | konstanta: `roundSize` 10 soal · `secondsPerQuestion` 15 · `scorePerCorrect` 100 · `coinsPerCorrect` 10 (keputusan WF-09, **K-46**) |
| `:282` | `buildRound`: *"sebagian dari bank lokal + soal dari koleksi pengguna bila tersedia; urutan opsi diacak agar posisi jawaban benar tidak selalu A"* |
| `:302` | `collectionQuestions`: *"tebak penulis dari buku miliknya. Butuh ≥ 2 buku dengan penulis berbeda; pengecoh diambil dari penulis lain di koleksi, dilengkapi opsi generik bila kurang dari 4"* (K-48) |

Bank lokal: **31 soal** tebak penulis/judul/genre — cukup untuk ronde penuh tanpa koleksi (`:31`).

### `lib/features/game/quiz_session.dart`
| Lokasi | Komentar |
|---|---|
| `:6` | *"Mesin kuis Book Trivia — state murni tanpa UI (mudah diuji unit). Satu QuizSession = satu ronde 10 soal."* |
| `:50/:53` | skor kumulatif 100 × benar · koin 10 × benar |
| `:56` | `answer()` idempoten — jawaban ganda diabaikan |
| `:70` | `timeout()` — soal habis waktu tanpa pilihan |
| `:78` | `next()` — soal terakhir → ronde selesai (`false`) |

### `lib/features/game/game_screen.dart`
| Lokasi | Komentar |
|---|---|
| `:22` | *"SCR-16 — Permainan Book Trivia (F-13 · WF-09). 10 soal pilihan ganda, timer 15 detik/soal **berbasis timestamp**, skor → koin, hasil tersimpan di `game_scores` (skor tertinggi + total koin untuk segmen Game SCR-04 & statistik SCR-09)."* |
| `:34/:37` | `questionSeconds` & `questionsOverride` — parameter injeksi untuk test deterministik (TC-28) |
| `:51` | `_questionStartMs` — epoch ms saat soal dimulai = dasar timer timestamp (**K-47**; `Timer.periodic(200 ms)` hanya render ulang) |

### `lib/core/db/game_score_repository.dart`
| Lokasi | Komentar |
|---|---|
| `:33` | *"Setiap ronde yang selesai menambah satu baris; skor tertinggi = `MAX(score)`, total koin = `SUM(coins)` (dipakai statistik SCR-09)"* |
| `:43/:61/:70/:79` | `save` (TC-28) · `bestScore` (null bila belum pernah) · `playCount` · `totalCoins` |

### Segmen Game SCR-04 — `features/explore/explore_screen.dart`
| Lokasi | Komentar |
|---|---|
| `:17` | *"Data ringkas segmen Game SCR-04: skor tertinggi + total koin (WF-09)"* |
| `:26` | `gameSummaryProvider` — *"Memuat rekor dari `game_scores` untuk kartu 'Book Trivia Challenge'"* |

## 3. API yang dipakai

Tidak ada — fitur **offline penuh** (bank soal lokal). Skor dikirim ke server hanya sebagai bagian `POST /sync`? **Tidak** — tabel `game_scores` lokal-murni (tidak termasuk payload sync, lihat `sync_service`); cukup untuk statistik di perangkat.

## 4. Test & keputusan

- **TC-28** `test/game_test.dart` — selesaikan 10 soal benar → skor **1000** & koin **100** tersimpan di `game_scores`.
- Tambahan: unit `QuestionBank` (ronde selalu 10 soal; soal koleksi dari ≥ 2 penulis berbeda), unit `QuizSession` (salah/timeout tidak menambah skor), test Main Lagi (2 baris skor), timer timeout → lanjut, segmen Game SCR-04 (ValueKey `game-best-score`/`game-coins`), koleksi → soal tambahan, statistik koin profil `SUM`.
- Keputusan: **K-46** (formula 100 poin/10 koin), **K-47** (timer timestamp), **K-48** (bank lokal 31 soal + koleksi + opsi generik), **K-49** (haptic `unawaited(...catchError)` — kanal platform tidak merespons di host test).
- Prinsip yang sama dengan stopwatch SCR-15: **timer dihitung dari timestamp, bukan penghitung per detik** (ketentuan dosen).

import 'dart:math';

import '../../core/models/book.dart';

/// Satu soal Book Trivia (F-13): pilihan ganda 4 opsi.
class TriviaQuestion {
  const TriviaQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.category,
  });

  /// Teks pertanyaan (mis. "Siapa penulis Laskar Pelangi?").
  final String prompt;

  /// 4 opsi jawaban; [correctIndex] menunjuk yang benar.
  final List<String> options;

  final int correctIndex;

  /// Kategori ringkas untuk label: `penulis` / `judul` / `genre`.
  final String category;
}

/// Bank soal lokal Book Trivia (deskripsi Bagian 5.8 — soal bawaan offline).
///
/// Materi: tebak penulis, judul, dan genre buku populer (sastra Indonesia
/// & dunia) agar tetap relevan dengan tema aplikasi membaca.
abstract final class QuestionBank {
  /// Soal bawaan (offline); cukup ≥ 10 agar ronde penuh tanpa koleksi.
  static const List<TriviaQuestion> local = <TriviaQuestion>[
    TriviaQuestion(
      prompt: 'Siapa penulis novel "Laskar Pelangi"?',
      options: ['Andrea Hirata', 'Pramoedya Ananta Toer', 'Dee Lestari',
        'Tere Liye'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Novel "Bumi Manusia" ditulis oleh…',
      options: ['Pramoedya Ananta Toer', 'Ahmad Tohari', 'Eka Kurniawan',
        'Sapardi Djoko Damono'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis trilogi "Bumi" (seri Avatar)?',
      options: ['Tere Liye', 'Andrea Hirata', 'Raditya Dika',
        'Winter Emsky'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Karya "Filosofi Teras" ditulis oleh…',
      options: ['Henry Manampiring', 'Raditya Dika', 'J.S. Khairen',
        'Deddy Corbuzier'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis novel "Perahu Kertas"?',
      options: ['Dee Lestari', 'Martha Tilaar', 'Sri Utami',
        'Rutvi Isdariyani'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Novel "Ayat-Ayat Cinta" karya…',
      options: ['Habiburrahman El Shirazy', 'Ahmad Fuadi', 'Hlamin',
        'Najwa Shihab'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis buku "Negeri 5 Menara"?',
      options: ['Ahmad Fuadi', 'Andrea Hirata', 'Tere Liye',
        'Piet Kilo'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Penulis novel "Cantik Itu Luka" adalah…',
      options: ['Eka Kurniawan', 'Leila S. Chudori', 'Intan Paramadita',
        'Djenar Maesa Ayu'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis kumpulan puisi "Hujan Bulan Juni"?',
      options: ['Sapardi Djoko Damono', 'WS Rendra', 'Chairil Anwar',
        'Goenawan Mohamad'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Novel "Sang Pemimpi" adalah karya…',
      options: ['Andrea Hirata', 'Tere Liye', 'Dee Lestari',
        'Piet Kilo'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Judul novel detektif karya Andrea Hirata selain Laskar Pelangi…',
      options: ['Edensor', 'Ayat-Ayat Cinta', 'Negeri 5 Menara',
        'Laskar Pelangi 2'],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Buku "Sapiens: A Brief History of Humankind" ditulis oleh…',
      options: ['Yuval Noah Harari', 'Stephen Hawking', 'Malcolm Gladwell',
        'Dan Brown'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis novel "The Alchemist" (Sang Alkemis)?',
      options: ['Paulo Coelho', 'Gabriel García Márquez', 'Haruki Murakami',
        'Dan Brown'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Novel "Laskar Pelangi" mengisahkan perjuangan…',
      options: [
        'Murid sekolah Muhammadiyah di Belitung',
        'Petani di Jawa Tengah',
        'Nelayan di Sulawesi',
        'Mahasiswa di Jakarta',
      ],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Kisah "Bumi Manusia" berlatar pada masa…',
      options: [
        'Pendudukan Belanda di Jawa',
        'Kemerdekaan Indonesia 1945',
        'Reformasi 1998',
        'Masa Kerajaan Majapahit',
      ],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Tokoh utama "Bumi Manusia" adalah…',
      options: ['Minke', 'Tirto Adhi Soerjo', 'Annelies', 'Hayati'],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Genre novel "Laskar Pelangi" paling tepat…',
      options: ['Inspiratif / Drama', 'Horor', 'Fiksi Ilmiah', 'Thriller'],
      correctIndex: 0,
      category: 'genre',
    ),
    TriviaQuestion(
      prompt: 'Genre buku "Filosofi Teras" termasuk…',
      options: ['Populer / Filsafat', 'Horor', 'Romansa', 'Petualangan'],
      correctIndex: 0,
      category: 'genre',
    ),
    TriviaQuestion(
      prompt: 'Novel "Cantik Itu Luka" masuk genre…',
      options: ['Magis Realisme', 'Fiksi Ilmiah', 'Detektif', 'Puisi'],
      correctIndex: 0,
      category: 'genre',
    ),
    TriviaQuestion(
      prompt: 'Buku "Sapiens" termasuk kategori…',
      options: ['Sejarah / Nonfiksi', 'Novel Romansa', 'Horor',
        'Komik'],
      correctIndex: 0,
      category: 'genre',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis novel "Ayat-Ayat Cinta 2"?',
      options: [
        'Habiburrahman El Shirazy',
        'Ahmad Fuadi',
        'Dee Lestari',
        'Tere Liye',
      ],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Karya "Malam Terakhir" dan "Rumi" karya penyair…',
      options: ['Jalaluddin Rumi', 'WS Rendra', 'Chairil Anwar',
        'Pramoedya'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Judul buku motivasi karya Mario Teguh yang terkenal…',
      options: [
        'Kesuksesan Bukan Kebetulan',
        'Negeri 5 Menara',
        'Sang Alkemis',
        'Bumi Manusia',
      ],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Novel "Hujan" karya…',
      options: ['Tere Liye', 'Dee Lestari', 'Eka Kurniawan',
        'Ahmad Fuadi'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Penulis serial buku "Gordas" (humor) adalah…',
      options: ['Raditya Dika', 'Piet Kilo', 'Jokowi', 'Deddy Corbuzier'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Buku "Atomic Habits" ditulis oleh…',
      options: ['James Clear', 'Stephen Covey', 'Dale Carnegie',
        'Robin Sharma'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Genre "Atomic Habits" adalah…',
      options: ['Pengembangan diri', 'Horor', 'Romansa', 'Fiksi ilmiah'],
      correctIndex: 0,
      category: 'genre',
    ),
    TriviaQuestion(
      prompt: 'Siapa penulis novel "Pulang" dari Lumbung Pustaka?',
      options: ['Tere Liye', 'Andrea Hirata', 'Dee Lestari',
        'Rutvi Isdariyani'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Kisah "Negeri 5 Menara" berlatar di…',
      options: [
        'Pondok modern Gontor',
        'Universitas Indonesia',
        'SMA di Bandung',
        'Pesantren Luhur',
      ],
      correctIndex: 0,
      category: 'judul',
    ),
    TriviaQuestion(
      prompt: 'Penulis esai "Catatan Pinggir" yang dikenal pembaca…',
      options: ['Goenawan Mohamad', 'WS Rendra', 'Pramoedya',
        'Nh. Dini'],
      correctIndex: 0,
      category: 'penulis',
    ),
    TriviaQuestion(
      prompt: 'Novel "Sang Alkemis" (The Alchemist) mengisahkan…',
      options: [
        'Perjalanan mencari harta karun & mimpi',
        'Kehidupan di Mars',
        'Detektif di London',
        'Kisah cinta di Paris',
      ],
      correctIndex: 0,
      category: 'judul',
    ),
  ];

  /// Jumlah soal per ronde (deskripsi Bagian 5.8).
  static const int roundSize = 10;

  /// Durasi per soal dalam detik (deskripsi Bagian 5.8).
  static const int secondsPerQuestion = 15;

  /// Skor per jawaban benar (keputusan WF-09).
  static const int scorePerCorrect = 100;

  /// Koin per jawaban benar (keputusan WF-09).
  static const int coinsPerCorrect = 10;

  /// Membangun ronde [roundSize] soal: sebagian dari bank lokal + soal
  /// dari koleksi pengguna bila tersedia (deskripsi Bagian 5.8).
  ///
  /// Urutan opsi diacak agar posisi jawaban benar tidak selalu A.
  /// [books] = koleksi non-wishlist milik pengguna (boleh kosong).
  static List<TriviaQuestion> buildRound({
    required List<Book> books,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = <TriviaQuestion>[...local, ...collectionQuestions(books, rng)];
    pool.shuffle(rng);
    final round =
        pool.take(roundSize).map((q) => _shuffledOptions(q, rng)).toList();
    // Pastikan selalu penuh walau pool < 10 (koleksi sangat kecil).
    while (round.length < roundSize && pool.isNotEmpty) {
      round.add(_shuffledOptions(pool[round.length % pool.length], rng));
    }
    return round;
  }

  /// Mengacak posisi opsi dan menghitung ulang [TriviaQuestion.correctIndex]
  /// agar jawaban benar tidak selalu di pilihan A — seluruh soal bank lokal
  /// didefinisikan dengan `correctIndex: 0`.
  static TriviaQuestion _shuffledOptions(TriviaQuestion q, Random rng) {
    final correctText = q.options[q.correctIndex];
    final options = <String>[...q.options]..shuffle(rng);
    return TriviaQuestion(
      prompt: q.prompt,
      options: options,
      correctIndex: options.indexOf(correctText),
      category: q.category,
    );
  }

  /// Soal dari koleksi pengguna: tebak penulis dari buku miliknya.
  ///
  /// Butuh ≥ 2 buku dengan penulis berbeda; pengecoh diambil dari penulis
  /// lain di koleksi, dilengkapi opsi generik bila kurang dari 4.
  static List<TriviaQuestion> collectionQuestions(
    List<Book> books,
    Random rng,
  ) {
    final usable = books
        .where((b) => b.title.trim().isNotEmpty && b.author.trim().isNotEmpty)
        .map((b) => (title: b.title.trim(), author: b.author.trim()))
        .toList();
    if (usable.length < 2) return const <TriviaQuestion>[];

    final authors = usable.map((b) => b.author).toSet().toList();
    if (authors.length < 2) return const <TriviaQuestion>[];

    const genericOptions = <String>[
      'Penulis Lain',
      'Anonim',
      'Tim Editorial',
      'Kontributor Tamu',
    ];

    final result = <TriviaQuestion>[];
    for (final book in usable) {
      final distractors =
          authors.where((a) => a != book.author).toList()..shuffle(rng);
      final options = <String>[book.author, ...distractors.take(3)];
      for (final g in genericOptions) {
        if (options.length >= 4) break;
        if (!options.contains(g)) options.add(g);
      }
      if (options.length < 4) continue;
      final correct = book.author;
      options.shuffle(rng);
      result.add(TriviaQuestion(
        prompt: 'Siapa penulis "${book.title}" di koleksimu?',
        options: options,
        correctIndex: options.indexOf(correct),
        category: 'penulis',
      ));
    }
    return result;
  }
}

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/blockchain/hash_chain.dart';
import '../../core/db/book_repository.dart';
import '../../core/db/block_repository.dart';
import '../../core/db/game_score_repository.dart';
import '../../core/db/note_quote_repository.dart';
import '../../core/db/reading_session_repository.dart';
import '../../core/db/review_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/book.dart';
import '../../core/models/note_quote.dart';
import '../../core/models/reading_session.dart';
import '../../core/models/review.dart';
import 'user_repository.dart';

/// Seeder akun demo berisi data contoh (khusus build `DEMO_MODE`).
///
/// Membuat akun [email]/[password] bila belum ada, lalu menanam koleksi
/// buku, sesi baca (streak), catatan/kutipan, ulasan + blok hash chain,
/// pengaturan, kesan & saran, serta skor game — agar tampilan aplikasi
/// terlihat penuh saat demo (keputusan 52).
///
/// Idempoten: bila akun sudah ada dan koleksi sudah terisi, hanya
/// mengembalikan `userId` tanpa menambah data ganda.
class DemoSeeder {
  DemoSeeder(this._db);

  final Database _db;

  static const String email = 'demo@storyloka.app';
  static const String password = 'Demo1234!';
  static const String name = 'Demo Pembaca';

  /// Memastikan akun demo + data contoh siap; mengembalikan `userId`.
  Future<int> ensure() async {
    final users = UserRepository(_db);
    var user = await users.findByEmailOrName(email);
    user ??= await users.register(name: name, email: email, password: password);

    final existing = await _db.query(
      'books',
      where: 'user_id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await _seedAll(user.id);
    }
    return user.id;
  }

  Future<void> _seedAll(int userId) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    int daysAgo(int d, {int hour = 20, int minute = 0}) => DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(Duration(days: d)).millisecondsSinceEpoch;

    // Bulan berjalan (untuk 2 buku selesai bulan ini → target tercapai sebagian).
    final monthStart = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

    final books = BookRepository(_db);
    final sessions = ReadingSessionRepository(_db);
    final notes = NoteQuoteRepository(_db);
    final reviews = ReviewRepository(_db);
    final blocks = BlockRepository(_db);
    final settings = SettingsRepository(_db);
    final game = GameScoreRepository(_db);

    final bookIds = <String, int>{};

    Future<int> addBook(Book b) async {
      final id = await books.insert(b);
      bookIds[b.title] = id;
      return id;
    }

    // ── Buku selesai (2 selesai bulan ini, 3 bulan lalu) ──────────────
    final completed = <Map<String, Object?>>[
      {
        'title': 'Laskar Pelangi',
        'author': 'Andrea Hirata',
        'publisher': 'Bentang Pustaka',
        'year': 2005,
        'isbn': '9789791227537',
        'genre': 'Fiksi',
        'pages': 252,
        'rating': 4.5,
        'review':
            'Kisah haru tentang perjuangan belajar yang menggugah semangat. '
            'Sederhana namun sangat menyentuh — wajib baca.',
        'finishedDaysAgo': 6,
      },
      {
        'title': 'Bumi Manusia',
        'author': 'Pramoedya Ananta Toer',
        'publisher': 'Kepustakaan Populer',
        'year': 1980,
        'isbn': '9789791227667',
        'genre': 'Sastra',
        'pages': 538,
        'rating': 5.0,
        'review':
            'Masterpiece sastra Indonesia. Kedalaman karakter Minke membuat '
            'pembaca ikut merasakan pergulatan zaman kolonial.',
        'finishedDaysAgo': 12,
      },
      {
        'title': 'Atomic Habits',
        'author': 'James Clear',
        'publisher': 'Gramedia Pustaka Utama',
        'year': 2018,
        'isbn': '9780735211292',
        'genre': 'Pengembangan Diri',
        'pages': 320,
        'rating': 4.5,
        'review':
            'Praktis dan mudah diterapkan. Sistem kecil yang konsisten '
            'terbukti mengubah kebiasaan jangka panjang.',
        'finishedDaysAgo': 70,
      },
      {
        'title': 'Ayat-Ayat Cinta',
        'author': 'Habiburrahman El Shirazy',
        'publisher': 'Republika',
        'year': 2004,
        'isbn': '9789793455549',
        'genre': 'Romance',
        'pages': 434,
        'rating': 4.0,
        'review':
            'Romansa yang lekat dengan nilai spiritual. Dibaca sekali duduk '
            'karena alur yang mengalir.',
        'finishedDaysAgo': 100,
      },
      {
        'title': 'Tenggelamnya Kapal van der Wijck',
        'author': 'Hamka',
        'publisher': 'Republika',
        'year': 1938,
        'isbn': '9789791227735',
        'genre': 'Sastra',
        'pages': 360,
        'rating': 4.5,
        'review':
            'Klasik yang tidak kehilangan pesona. Cinta yang dikorbankan '
            'karena adat, tragis namun bermartabat.',
        'finishedDaysAgo': 140,
      },
    ];

    final completedIds = <int>[];
    final reviewTexts = <int, String>{};
    final finishedDates = <int, int>{};

    for (final c in completed) {
      final finishedAt = daysAgo(c['finishedDaysAgo'] as int, hour: 21);
      // finishedDaysAgo 6 & 12 masih bisa jatuh di bulan lalu; paksa 2
      // terbaru agar berada di bulan berjalan (target bulanan demo).
      final adjusted = c['finishedDaysAgo'] == 6
          ? DateTime(now.year, now.month, now.day, 21)
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch
          : c['finishedDaysAgo'] == 12
              ? (monthStart + const Duration(days: 3).inMilliseconds)
              : finishedAt;
      final id = await addBook(
        Book(
          userId: userId,
          title: c['title'] as String,
          author: c['author'] as String,
          publisher: c['publisher'] as String?,
          year: c['year'] as int?,
          isbn: c['isbn'] as String?,
          genre: c['genre'] as String?,
          pages: c['pages'] as int?,
          cover: 'https://covers.openlibrary.org/b/isbn/${c['isbn']}-L.jpg',
          synopsis: 'Data contoh untuk demo Storyloka.',
          status: 'completed',
          rating: (c['rating'] as num).toDouble(),
          startedAt: adjusted - const Duration(days: 20).inMilliseconds,
          finishedAt: adjusted,
          updatedAt: adjusted,
        ),
      );
      completedIds.add(id);
      reviewTexts[id] = c['review'] as String;
      finishedDates[id] = adjusted;
    }

    // ── Buku sedang dibaca ────────────────────────────────────────────
    final reading = <Map<String, Object?>>[
      {
        'title': 'Filosofi Teras',
        'author': 'Henry Manampiring',
        'publisher': 'Kompas',
        'year': 2019,
        'isbn': '9786024122196',
        'genre': 'Filsafat',
        'pages': 372,
        'progressPage': 148,
        'synopsis':
            'Pengantar filsafat Stoic yang ringan untuk kehidupan sehari-hari.',
      },
      {
        'title': 'Hujan',
        'author': 'Tere Liye',
        'publisher': 'Gramedia Pustaka Utama',
        'year': 2016,
        'isbn': '9786020518367',
        'genre': 'Fiksi',
        'pages': 424,
        'progressPage': 106,
        'synopsis': 'Petualangan lintas waktu yang dibalut kisah persahabatan.',
      },
    ];

    for (var i = 0; i < reading.length; i++) {
      final r = reading[i];
      final startedAt = daysAgo(10 - i * 2, hour: 19);
      final id = await addBook(
        Book(
          userId: userId,
          title: r['title'] as String,
          author: r['author'] as String,
          publisher: r['publisher'] as String?,
          year: r['year'] as int?,
          isbn: r['isbn'] as String?,
          genre: r['genre'] as String?,
          pages: r['pages'] as int?,
          cover: 'https://covers.openlibrary.org/b/isbn/${r['isbn']}-L.jpg',
          synopsis: r['synopsis'] as String?,
          status: 'reading',
          startedAt: startedAt,
          updatedAt: nowMs,
        ),
      );
      // Sesi baca 6 hari terakhir (streak demo) + progres halaman.
      final target = r['progressPage'] as int;
      for (var d = 0; d < 6; d++) {
        final page = (target * (6 - d) / 6).round().clamp(1, target);
        await sessions.insert(
          ReadingSession(
            bookId: id,
            startTs: daysAgo(d, hour: 19 + (d.isEven ? 0 : 1)),
            durationSec: 1800 + (d * 600),
            lastPage: page,
            note: d == 0 ? 'Lanjutkan dari bab sebelumnya.' : null,
            updatedAt: daysAgo(d),
          ),
        );
      }
    }

    // ── Buku belum dibaca & wishlist ──────────────────────────────────
    final others = <Map<String, Object?>>[
      {
        'title': 'Sapiens',
        'author': 'Yuval Noah Harari',
        'publisher': 'Kompas',
        'year': 2011,
        'isbn': '9780062316103',
        'genre': 'Sejarah',
        'pages': 512,
        'status': 'unread',
      },
      {
        'title': 'Negeri 5 Menara',
        'author': 'Ahmad Fuadi',
        'publisher': 'Republika',
        'year': 2009,
        'isbn': '9786027730328',
        'genre': 'Fiksi',
        'pages': 440,
        'status': 'unread',
      },
      {
        'title': 'Dilan 1990',
        'author': 'Pidi Baiq',
        'publisher': 'Pastel Books',
        'year': 2014,
        'isbn': '9786029478136',
        'genre': 'Romance',
        'pages': 336,
        'status': 'wishlist',
      },
      {
        'title': 'Sebuah Seni untuk Bersikap Bodo Amat',
        'author': 'Rolf Dobelli',
        'publisher': 'Gramedia Pustaka Utama',
        'year': 2015,
        'isbn': '9786020503325',
        'genre': 'Pengembangan Diri',
        'pages': 208,
        'status': 'wishlist',
      },
    ];
    for (final o in others) {
      await addBook(
        Book(
          userId: userId,
          title: o['title'] as String,
          author: o['author'] as String,
          publisher: o['publisher'] as String?,
          year: o['year'] as int?,
          isbn: o['isbn'] as String?,
          genre: o['genre'] as String?,
          pages: o['pages'] as int?,
          cover: 'https://covers.openlibrary.org/b/isbn/${o['isbn']}-L.jpg',
          synopsis: 'Data contoh untuk demo Storyloka.',
          status: o['status'] as String,
          updatedAt: nowMs,
        ),
      );
    }

    // ── Sesi tambahan buku selesai (total jam realistis) ──────────────
    for (final id in completedIds) {
      final rows = await _db.query(
        'books',
        columns: ['pages', 'finished_at', 'started_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final pages = (rows.first['pages'] as int?) ?? 200;
      final finished = (rows.first['finished_at'] as int?) ?? nowMs;
      for (var k = 0; k < 4; k++) {
        await sessions.insert(
          ReadingSession(
            bookId: id,
            startTs: finished - const Duration(days: 7).inMilliseconds +
                k * const Duration(days: 2).inMilliseconds,
            durationSec: 2400 + k * 900,
            lastPage: ((pages * (k + 1)) / 4).round(),
            updatedAt: finished,
          ),
        );
      }
    }

    // ── Catatan & kutipan ─────────────────────────────────────────────
    final firstReadingId = bookIds[reading.first['title']];
    final laskarId = bookIds['Laskar Pelangi'];
    final terasId = bookIds['Filosofi Teras'];
    if (firstReadingId != null) {
      await notes.insert(
        NoteQuote(
          bookId: firstReadingId,
          type: 'note',
          content: 'Konsep dichotomous control mulai jelas — terapkan minggu ini.',
          page: 140,
          createdAt: daysAgo(1),
        ),
      );
      await notes.insert(
        NoteQuote(
          bookId: firstReadingId,
          type: 'quote',
          content: 'Kita tidak bisa mengendalikan peristiwa, tetapi bisa '
              'mengendalikan penilaian kita terhadapnya.',
          page: 88,
          createdAt: daysAgo(3),
        ),
      );
    }
    if (laskarId != null) {
      await notes.insert(
        NoteQuote(
          bookId: laskarId,
          type: 'quote',
          content: 'Hiduplah seperti seberkas cahaya, meski kecil, ia mampu '
              'menerangi kegelapan.',
          page: 251,
          createdAt: daysAgo(5),
        ),
      );
    }
    if (terasId != null) {
      await notes.insert(
        NoteQuote(
          bookId: terasId,
          type: 'note',
          content: 'Bandingkan dengan konsep mindfulness.',
          page: 60,
          createdAt: daysAgo(2),
        ),
      );
    }

    // ── Ulasan + blok hash chain (Proof of Reading) ───────────────────
    var previousHash = HashChain.genesisPreviousHash;
    var idx = 0;
    for (final id in completedIds) {
      final text = reviewTexts[id]!;
      final finished = finishedDates[id]!;
      await reviews.insert(
        Review(
          bookId: id,
          rating: (completed.firstWhere((c) => bookIds[c['title']] == id)['rating']
                  as num)
              .toDouble(),
          text: text,
          createdAt: finished,
        ),
      );
      final block = HashChain.buildBlock(
        idx: idx,
        userId: userId,
        bookId: id,
        reviewText: text,
        finishedDate: finished,
        previousHash: previousHash,
        timestamp: finished,
      );
      await blocks.append(block);
      previousHash = block.hash;
      idx++;
    }

    // ── Pengaturan (target bulanan 4, pengingat 20:00) ────────────────
    await settings.ensureRow(userId);
    await _db.update(
      'settings',
      AppSettings(
        userId: userId,
        reminderOn: true,
        reminderTime: '20:00',
        themeMode: 'auto',
        streakNotify: true,
        monthlyTarget: 4,
        updatedAt: nowMs,
      ).toRow(),
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // ── Kesan & saran (data contoh) ───────────────────────────────────
    await _db.insert(
      'feedback',
      <String, Object?>{
        'user_id': userId,
        'kesan': 'Mata kuliah PAM sangat menarik karena langsung praktik '
            'membangun aplikasi nyata; materi state management dan penyimpanan '
            'lokal sangat membantu memahami arsitektur mobile modern.',
        'saran': 'Semoga ada sesi code review kelompok tambahan dan studi '
            'kasus fitur keamanan (enkripsi) lebih dalam.',
        'updated_at': nowMs,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ── Skor game (3 ronde) ───────────────────────────────────────────
    await game.save(userId: userId, score: 600, coins: 60, playedAt: daysAgo(4, hour: 22));
    await game.save(userId: userId, score: 850, coins: 85, playedAt: daysAgo(2, hour: 21));
    await game.save(userId: userId, score: 1000, coins: 100, playedAt: daysAgo(1, hour: 22));

    // ── Riwayat notifikasi contoh ─────────────────────────────────────
    await _db.insert('notifications', <String, Object?>{
      'user_id': userId,
      'type': 'certificate',
      'title': 'Sertifikat Diterbitkan',
      'body': 'Buku "Laskar Pelangi" selesai dibaca — sertifikat siap.',
      'ref': laskarId != null ? '/book/$laskarId' : null,
      'read': 0,
      'created_at': finishedDates[laskarId] ?? nowMs,
    });
    await _db.insert('notifications', <String, Object?>{
      'user_id': userId,
      'type': 'reminder',
      'title': 'Waktunya membaca!',
      'body': 'Sesi membaca hari ini belum dicatat. Ayo mulai 15 menit saja.',
      'read': 1,
      'created_at': daysAgo(1, hour: 20),
    });
  }
}

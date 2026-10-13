import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/book_repository.dart';
import '../../core/db/database_provider.dart';
import '../../core/db/note_quote_repository.dart';
import '../../core/db/reading_session_repository.dart';
import '../../core/db/review_repository.dart';
import '../../core/models/book.dart';
import '../../core/models/note_quote.dart';
import '../../core/models/review.dart';
import '../../core/utils/reading_stats.dart';
import '../../features/auth/auth_controller.dart';

/// Seluruh data SCR-06 dalam satu async provider: buku + progres halaman
/// (dari sesi terakhir), total jam, streak, catatan, dan ulasan.
class BookDetailData {
  const BookDetailData({
    required this.book,
    required this.lastPage,
    required this.totalSec,
    required this.streakDays,
    required this.reviews,
    required this.notes,
  });

  final Book book;

  /// Halaman terakhir terjauh dari seluruh sesi baca buku ini.
  final int lastPage;

  /// Total durasi (detik) seluruh sesi buku ini.
  final int totalSec;

  /// Streak membaca global (hari berturut-turut, Bagian 5.4).
  final int streakDays;

  final List<Review> reviews;
  final List<NoteQuote> notes;

  /// 0…1 progres halaman; 0 bila halaman tidak diketahui.
  double get progress {
    final pages = book.pages;
    if (pages == null || pages <= 0) return 0;
    return (lastPage / pages).clamp(0.0, 1.0);
  }

  int get hoursRead => (totalSec / 3600).round();
}

final bookDetailProvider = FutureProvider.autoDispose
    .family<BookDetailData?, int>((ref, bookId) async {
  final db = await ref.watch(databaseProvider.future);
  final sessionRepo = await ref.watch(readingSessionRepositoryProvider.future);
  final reviewRepo = await ref.watch(reviewRepositoryProvider.future);
  final noteRepo = await ref.watch(noteQuoteRepositoryProvider.future);
  final bookRepo = await ref.watch(bookRepositoryProvider.future);
  if (db == null || bookRepo == null) return null;

  final book = await bookRepo.get(bookId);
  if (book == null) return null;

  final userId = ref.watch(authControllerProvider).userId ?? book.userId;
  final stats = await ReadingStats.load(db, userId);

  return BookDetailData(
    book: book,
    lastPage: await sessionRepo?.furthestPage(bookId) ?? 0,
    totalSec: await sessionRepo?.totalDurationSec(bookId) ?? 0,
    streakDays: stats.streakDays,
    reviews: await reviewRepo?.listByBook(bookId) ?? const <Review>[],
    notes: await noteRepo?.listByBook(bookId) ?? const <NoteQuote>[],
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/book_repository.dart';
import '../../core/db/database_provider.dart';
import '../../core/db/reading_session_repository.dart';
import '../../core/models/book.dart';
import '../../core/utils/reading_stats.dart';
import '../auth/auth_controller.dart';

/// Seluruh data SCR-02 dalam satu async provider: ringkasan baca
/// (Reading Summary), buku Currently Reading (+ progres halaman),
/// dan carousel My Collection.
class HomeData {
  const HomeData({
    required this.stats,
    required this.collection,
    this.currentLastPage = 0,
  });

  final ReadingStats stats;

  /// Beberapa buku terbaru (semua status) untuk carousel My Collection.
  final List<Book> collection;

  /// Halaman terakhir terjauh pada buku Currently Reading.
  final int currentLastPage;

  /// 0…1 progres buku Currently Reading.
  double get currentProgress {
    final book = stats.currentlyReading;
    final pages = book?.pages;
    if (pages == null || pages <= 0) return 0;
    return (currentLastPage / pages).clamp(0.0, 1.0);
  }
}

final homeDataProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  const empty = HomeData(
    stats: ReadingStats.empty,
    collection: <Book>[],
  );
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return empty;
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return empty;

  final stats = await ReadingStats.load(db, userId);
  final repo = await ref.watch(bookRepositoryProvider.future);
  final collection = repo == null
      ? const <Book>[]
      : await repo.list(userId, orderBy: 'updated_at DESC');

  final current = stats.currentlyReading;
  final sessionRepo = await ref.watch(readingSessionRepositoryProvider.future);
  final currentLastPage =
      current?.id == null ? 0 : await sessionRepo?.furthestPage(current!.id!) ?? 0;

  return HomeData(
    stats: stats,
    collection: collection,
    currentLastPage: currentLastPage,
  );
});

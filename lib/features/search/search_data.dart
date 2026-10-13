import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/book_repository.dart';
import '../../core/models/book.dart';
import '../../core/network/book_search_service.dart';
import '../auth/auth_controller.dart';
import '../home/home_data.dart';
import '../library/library_data.dart';

/// Kata kunci pencarian online (SCR-08 tab "Cari Online").
///
/// Dipisah dari [libraryFilterProvider] agar pencarian online hanya
/// berjalan saat pengguna menekan tombol cari (hemat kuota API publik).
class OnlineSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void submit(String value) => state = value.trim();
}

final onlineSearchQueryProvider =
    NotifierProvider<OnlineSearchNotifier, String>(OnlineSearchNotifier.new);

/// Hasil pencarian online (Google Books / Open Library) — F-10.
final onlineResultsProvider =
    FutureProvider.autoDispose<List<OnlineBookResult>>((ref) async {
  final query = ref.watch(onlineSearchQueryProvider);
  if (query.length < 2) return const <OnlineBookResult>[];
  return ref.watch(bookSearchServiceProvider).search(query);
});

/// Menyimpan hasil pencarian online langsung ke koleksi/wishlist
/// (aksi `+ Koleksi` / `+ Wishlist` — Bagian 6 SCR-08).
Future<void> saveOnlineResult(
  WidgetRef ref,
  OnlineBookResult result,
  String status,
) async {
  final userId = ref.read(authControllerProvider).userId;
  final repo = await ref.read(bookRepositoryProvider.future);
  if (userId == null || repo == null) return;
  await repo.insert(
    Book(
      userId: userId,
      title: result.title,
      author: result.author,
      publisher: result.publisher,
      year: result.year,
      isbn: result.isbn,
      genre: result.genre,
      pages: result.pages,
      cover: result.cover,
      synopsis: result.synopsis,
      status: status,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  ref.invalidate(libraryBooksProvider);
  ref.invalidate(homeDataProvider);
}

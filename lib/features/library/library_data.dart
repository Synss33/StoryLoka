import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/book_repository.dart';
import '../../core/models/book.dart';
import '../../core/utils/book_status.dart';
import '../auth/auth_controller.dart';

/// Urutan sort yang tersedia di SCR-03/SCR-08 (Bagian 6 SCR-03).
enum LibrarySort {
  terbaru('Terbaru', 'updated_at DESC'),
  judul('Judul', 'title ASC'),
  rating('Rating', 'rating DESC'),
  penulis('Penulis', 'author ASC');

  const LibrarySort(this.label, this.orderBy);

  final String label;
  final String orderBy;
}

/// Tab segmented SCR-03 (Bagian 6 SCR-03): buku `wishlist` hanya muncul
/// di tab Wishlist, sisanya di Koleksi (dokumen desain Bagian 7).
enum LibraryTab {
  koleksi('Koleksi Saya'),
  wishlist('Wishlist');

  const LibraryTab(this.label);

  final String label;
}

/// Filter & pencarian buku yang dipakai SCR-03 (Library) dan SCR-08
/// (Pencarian). Semua perubahan memicu pemuatan ulang [libraryBooksProvider].
class LibraryFilter {
  const LibraryFilter({
    this.tab = LibraryTab.koleksi,
    this.query = '',
    this.status,
    this.genre,
    this.minRating,
    this.year,
    this.sort = LibrarySort.terbaru,
  });

  /// Tab segmented yang sedang aktif.
  final LibraryTab tab;

  /// Kata kunci pencarian lokal (judul/penulis/ISBN).
  final String query;

  /// Status tunggal dari bottom sheet filter SCR-08; `null` = semua status.
  final String? status;
  final String? genre;
  final double? minRating;
  final int? year;
  final LibrarySort sort;

  bool get hasFilter =>
      genre != null || minRating != null || year != null || status != null;

  LibraryFilter copyWith({
    LibraryTab? tab,
    String? query,
    String? status,
    String? genre,
    double? minRating,
    int? year,
    LibrarySort? sort,
    bool clearStatus = false,
    bool clearGenre = false,
    bool clearMinRating = false,
    bool clearYear = false,
  }) =>
      LibraryFilter(
        tab: tab ?? this.tab,
        query: query ?? this.query,
        status: clearStatus ? null : (status ?? this.status),
        genre: clearGenre ? null : (genre ?? this.genre),
        minRating: clearMinRating ? null : (minRating ?? this.minRating),
        year: clearYear ? null : (year ?? this.year),
        sort: sort ?? this.sort,
      );

  /// Kembali ke filter bersih (tombol Reset di SCR-08); tab tetap dipertahankan.
  LibraryFilter reset() => LibraryFilter(tab: tab);
}

/// State filter aktif (diketik/ketuk chip → provider ini berubah).
class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => const LibraryFilter();

  void setTab(LibraryTab tab) => state = state.copyWith(tab: tab);

  void setQuery(String value) => state = state.copyWith(query: value);

  void setStatus(BookStatus? status) => state = status == null
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status.code);

  void setGenre(String? genre) => state = genre == null
      ? state.copyWith(clearGenre: true)
      : state.copyWith(genre: genre);

  void setMinRating(double? rating) => state = rating == null
      ? state.copyWith(clearMinRating: true)
      : state.copyWith(minRating: rating);

  void setYear(int? year) => state = year == null
      ? state.copyWith(clearYear: true)
      : state.copyWith(year: year);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);

  /// Menerapkan hasil bottom sheet filter (draft dari SCR-03/SCR-08).
  void apply(LibraryFilter filter) => state = filter;
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
  LibraryFilterNotifier.new,
);

/// Daftar buku sesuai filter aktif — dipakai SCR-03 & SCR-08 tab lokal.
///
/// Pemetaan tab: `wishlist` → hanya status wishlist; `koleksi` → status
/// pilihan filter, atau (tanpa pilihan) selain wishlist.
final libraryBooksProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final filter = ref.watch(libraryFilterProvider);
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return const <Book>[];

  final repo = await ref.watch(bookRepositoryProvider.future);
  if (repo == null) return const <Book>[];

  final wishlistTab = filter.tab == LibraryTab.wishlist;
  return repo.list(
    userId,
    query: filter.query,
    status: wishlistTab ? 'wishlist' : filter.status,
    excludeWishlist: !wishlistTab && filter.status == null,
    genre: filter.genre,
    minRating: filter.minRating,
    year: filter.year,
    orderBy: filter.sort.orderBy,
  );
});

/// Daftar genre unik pengguna untuk bottom sheet filter SCR-08.
final libraryGenresProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return const <String>[];
  final repo = await ref.watch(bookRepositoryProvider.future);
  if (repo == null) return const <String>[];
  return repo.genres(userId);
});

/// Daftar tahun terbit unik pengguna untuk bottom sheet filter SCR-08.
final libraryYearsProvider =
    FutureProvider.autoDispose<List<int>>((ref) async {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return const <int>[];
  final repo = await ref.watch(bookRepositoryProvider.future);
  if (repo == null) return const <int>[];
  return repo.years(userId);
});

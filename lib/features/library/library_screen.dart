import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/book_repository.dart';
import '../../core/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/top_bar.dart';
import '../home/home_data.dart';
import 'book_tile.dart';
import 'filter_sheet.dart';
import 'library_data.dart';

/// SCR-03 — Library: Koleksi & Wishlist (F-10, WF-05).
///
/// Segmented Koleksi/Wishlist, pencarian singkat, bottom sheet Filter &
/// Sort, grid/list 2 kolom, long-press action sheet (Edit / Pindahkan /
/// Hapus), dan FAB Tambah Buku (satu-satunya FAB — Bagian 2, Zona 3).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// false = grid (default), true = daftar (toggle di top bar).
  bool _asList = false;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(libraryFilterProvider);
    final books = ref.watch(libraryBooksProvider);

    return Scaffold(
      appBar: StorylokaTopBar(
        title: 'Library',
        actions: [
          IconButton(
            key: const ValueKey<String>('goto-search'),
            tooltip: 'Cari buku',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            key: const ValueKey<String>('toggle-view'),
            tooltip: _asList ? 'Tampilan grid' : 'Tampilan daftar',
            icon: Icon(_asList ? Icons.grid_view_outlined : Icons.view_list_outlined),
            onPressed: () => setState(() => _asList = !_asList),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('add-book-fab'),
        tooltip: 'Tambah Buku',
        onPressed: () => context.push('/book/edit'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ---- Zona 2: kontrol atas ------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.grid,
              AppSpacing.screenMargin,
              0,
            ),
            child: Column(
              children: [
                SegmentedButton<LibraryTab>(
                  segments: [
                    for (final tab in LibraryTab.values)
                      ButtonSegment<LibraryTab>(
                        value: tab,
                        label: Text(tab.label),
                      ),
                  ],
                  selected: <LibraryTab>{filter.tab},
                  onSelectionChanged: (selection) =>
                      ref.read(libraryFilterProvider.notifier).setTab(selection.first),
                ),
                const SizedBox(height: AppSpacing.grid),
                TextField(
                  key: const ValueKey<String>('library-query'),
                  onChanged: (value) =>
                      ref.read(libraryFilterProvider.notifier).setQuery(value),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Cari judul / penulis / ISBN…',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.grid),
                Row(
                  children: [
                    _FilterButton(
                      active: filter.hasFilter,
                      label: 'Filter',
                      onTap: _openFilter,
                    ),
                    const SizedBox(width: AppSpacing.grid),
                    _FilterButton(
                      label: 'Urutkan: ${filter.sort.label}',
                      icon: Icons.swap_vert,
                      onTap: _openSort,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---- Zona 2: daftar buku --------------------------------------
          Expanded(
            child: books.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screenMargin),
                child: LoadingSkeleton.bookGrid(count: 6),
              ),
              error: (error, _) => ErrorState(
                message: 'Gagal memuat koleksi. Data lokal tetap tersimpan.',
                onRetry: () => ref.invalidate(libraryBooksProvider),
              ),
              data: (list) => list.isEmpty
                  ? _EmptyLibrary(query: filter.query, tab: filter.tab)
                  : _BookList(books: list, asList: _asList),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilter() async {
    final current = ref.read(libraryFilterProvider);
    final draft = await showLibraryFilterSheet(context, current);
    if (draft == null) return;
    ref.read(libraryFilterProvider.notifier).apply(draft);
  }

  Future<void> _openSort() async {
    final current = ref.read(libraryFilterProvider);
    final picked = await showModalBottomSheet<LibrarySort>(
      context: context,
      // Root navigator agar sheet berada di atas bottom nav.
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (sheetContext) {
        final sheetPalette = AppColors.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Urutkan berdasarkan', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.cardGap),
                Wrap(
                  spacing: AppSpacing.grid,
                  runSpacing: AppSpacing.grid,
                  children: [
                    for (final sort in LibrarySort.values)
                      ChoiceChip(
                        label: Text(sort.label),
                        selected: current.sort == sort,
                        onSelected: (_) => Navigator.pop(sheetContext, sort),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  'Diurutkan pada daftar Koleksi maupun hasil pencarian.',
                  style: AppTypography.caption
                      .copyWith(color: sheetPalette.neutral500),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    ref.read(libraryFilterProvider.notifier).setSort(picked);
  }
}

/// Tombol kontrol baris Filter/Sort (tinggi sentuh 48dp — Bagian 1.3).
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.onTap,
    this.icon = Icons.tune,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Container(
          height: AppSpacing.touchTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.grid),
          decoration: BoxDecoration(
            color: active ? p.primary50 : p.surface,
            borderRadius: AppRadius.pillAll,
            border: Border.all(color: active ? p.primary500 : p.neutral200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? p.primary600 : p.neutral500),
              const SizedBox(width: AppSpacing.micro),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body2.copyWith(
                    color: active ? p.primary600 : p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid (2 kolom) atau daftar buku + long-press action sheet SCR-03.
class _BookList extends ConsumerWidget {
  const _BookList({required this.books, required this.asList});

  final List<Book> books;
  final bool asList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asList) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenMargin,
          AppSpacing.grid,
          AppSpacing.screenMargin,
          88, // ruang bawah Master Layout Zona 2
        ),
        itemCount: books.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final book = books[index];
          return BookTile(
            book: book,
            onTap: () => context.push('/book/${book.id}'),
            onLongPress: () => _showActions(context, ref, book),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.cardGap;
        final cellWidth = (constraints.maxWidth - AppSpacing.screenMargin * 2 - gap) / 2;
        // Tinggi = cover 2:3 + baris teks (judul, penulis, rating/badge).
        final cellHeight = cellWidth * 1.5 + 92;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.grid,
            AppSpacing.screenMargin,
            88,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookCard(
              book: book,
              onTap: () => context.push('/book/${book.id}'),
              onLongPress: () => _showActions(context, ref, book),
            );
          },
        );
      },
    );
  }

  /// Action sheet long-press: Edit, Pindahkan, Hapus (Bagian 6 SCR-03).
  Future<void> _showActions(BuildContext context, WidgetRef ref, Book book) async {
    final p = AppColors.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      // Root navigator agar sheet berada di atas bottom nav.
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Text(book.title, style: AppTypography.h3, maxLines: 2),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(
                book.status == 'wishlist'
                    ? Icons.book_outlined
                    : Icons.favorite_outline,
              ),
              title: Text(
                book.status == 'wishlist'
                    ? 'Pindahkan ke Koleksi'
                    : 'Pindahkan ke Wishlist',
              ),
              onTap: () => Navigator.pop(sheetContext, 'move'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: p.danger500),
              title: Text('Hapus', style: TextStyle(color: p.danger500)),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: AppSpacing.grid),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final repo = await ref.read(bookRepositoryProvider.future);
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        context.push('/book/edit?id=${book.id}');
      case 'move':
        // Wishlist ↔ Koleksi (Bagian 7: wishlist hanya di tab Wishlist).
        final target = book.status == 'wishlist' ? 'unread' : 'wishlist';
        await repo?.update(book.copyWith(status: target));
        _refresh(ref);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Hapus buku?'),
            content: Text(
              '"${book.title}" akan disembunyikan dari koleksi. '
              'Data tetap tersimpan terenkripsi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              TextButton(
                key: const ValueKey<String>('confirm-delete-book'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await repo?.softDelete(book.id!);
          _refresh(ref);
        }
    }
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(libraryBooksProvider);
    ref.invalidate(homeDataProvider);
  }
}

/// State kosong SCR-12 untuk koleksi / wishlist / hasil pencarian.
class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary({required this.query, required this.tab});

  final String query;
  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'Tidak Ada Hasil',
        description: 'Tidak ada buku yang cocok dengan "$query".',
        actionLabel: 'Reset Pencarian',
        onAction: () => ref
            .read(libraryFilterProvider.notifier)
            .apply(LibraryFilter(tab: tab)),
      );
    }
    if (tab == LibraryTab.wishlist) {
      return EmptyState(
        icon: Icons.favorite_outline,
        title: 'Belum Ada di Wishlist',
        description: 'Tandai buku incaran agar mudah ditemukan nanti.',
        actionLabel: 'Cari Buku',
        onAction: () => context.push('/search'),
      );
    }
    return EmptyState(
      icon: Icons.auto_stories_outlined,
      title: 'Belum Ada Buku di Koleksi',
      description: 'Tambahkan buku pertamamu atau cari online.',
      actionLabel: 'Tambah Buku Baru',
      onAction: () => context.push('/book/edit'),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/book_search_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../library/book_tile.dart';
import '../library/filter_sheet.dart';
import '../library/library_data.dart';
import 'search_data.dart';

/// SCR-08 — Pencarian & Filter (F-10, WF-05).
///
/// Tab **Koleksi Saya** = pencarian lokal (judul/penulis/ISBN) + filter
/// lengkap; tab **Cari Online** = Google Books / Open Library dengan aksi
/// `Pilih` (form SCR-07 terisi otomatis — TC-13), `+ Wishlist`, `+ Koleksi`.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  /// true = tab Cari Online.
  bool _online = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    ref.read(libraryFilterProvider.notifier).setQuery(value);
    ref.read(onlineSearchQueryProvider.notifier).submit(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final filter = ref.watch(libraryFilterProvider);

    return Scaffold(
      // Zona 1 khusus SCR-08: kolom cari menggantikan judul (Bagian 6).
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(AppLayout.topBarHeight),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.micro),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.grid),
                Icon(Icons.search, size: 20, color: p.neutral500),
                const SizedBox(width: AppSpacing.micro),
                Expanded(
                  child: TextField(
                    key: const ValueKey<String>('search-field'),
                    controller: _controller,
                    onChanged: (value) => _submit(value),
                    onSubmitted: (value) => _submit(value),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Cari judul / penulis / ISBN…',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('search-cancel'),
                  onPressed: () => context.pop(),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ---- Tab lokal / online ---------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.grid,
              AppSpacing.screenMargin,
              0,
            ),
            child: SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('Koleksi Saya')),
                ButtonSegment<bool>(value: true, label: Text('Cari Online')),
              ],
              selected: <bool>{_online},
              onSelectionChanged: (selection) =>
                  setState(() => _online = selection.first),
            ),
          ),
          const SizedBox(height: AppSpacing.grid),

          // ---- Chip filter cepat ----------------------------------------
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
            child: Row(
              children: [
                _QuickChip(
                  label: filter.genre ?? 'Genre',
                  active: filter.genre != null,
                  onTap: _openFilter,
                ),
                const SizedBox(width: AppSpacing.grid),
                _QuickChip(
                  label: _statusLabel(filter.status),
                  active: filter.status != null,
                  onTap: _openFilter,
                ),
                const SizedBox(width: AppSpacing.grid),
                _QuickChip(
                  label: '★ 4+',
                  active: filter.minRating == 4,
                  onTap: () {
                    final notifier = ref.read(libraryFilterProvider.notifier);
                    filter.minRating == 4
                        ? notifier.setMinRating(null)
                        : notifier.setMinRating(4);
                  },
                ),
                const SizedBox(width: AppSpacing.grid),
                _QuickChip(
                  label: filter.year?.toString() ?? 'Tahun',
                  active: filter.year != null,
                  onTap: _openFilter,
                ),
                const SizedBox(width: AppSpacing.grid),
                _QuickChip(
                  label: 'Reset',
                  icon: Icons.close,
                  active: false,
                  onTap: () => ref
                      .read(libraryFilterProvider.notifier)
                      .apply(LibraryFilter(tab: filter.tab)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.grid),

          Expanded(
            child: _online ? _OnlineResults() : const _LocalResults(),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    if (status == null) return 'Status';
    return status[0].toUpperCase() + status.substring(1);
  }

  Future<void> _openFilter() async {
    final current = ref.read(libraryFilterProvider);
    final draft = await showLibraryFilterSheet(context, current);
    if (draft == null) return;
    ref.read(libraryFilterProvider.notifier).apply(draft);
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.active = false,
    this.icon,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.grid,
          vertical: AppSpacing.micro + 2,
        ),
        decoration: BoxDecoration(
          color: active ? p.primary50 : p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: active ? p.primary500 : p.neutral200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? p.primary600 : p.neutral500),
              const SizedBox(width: AppSpacing.micro),
            ],
            Text(
              label,
              style: AppTypography.body2.copyWith(
                color: active ? p.primary600 : p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hasil pencarian lokal dari SQLite (tetap berfungsi offline).
class _LocalResults extends ConsumerWidget {
  const _LocalResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryBooksProvider);
    final query = ref.watch(libraryFilterProvider).query;

    return books.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenMargin),
        child: LoadingSkeleton.list(count: 4),
      ),
      error: (error, _) => ErrorState(
        message: 'Gagal memuat hasil dari koleksi lokal.',
        onRetry: () => ref.invalidate(libraryBooksProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: query.trim().isEmpty ? 'Mulai Mengetik' : 'Tidak Ada Hasil',
            description: query.trim().isEmpty
                ? 'Cari judul, penulis, atau ISBN dari koleksi Anda.'
                : 'Tidak ada buku lokal yang cocok dengan "$query".',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.grid,
          ),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final book = list[index];
            return BookTile(book: book, onTap: () => context.push('/book/${book.id}'));
          },
        );
      },
    );
  }
}

/// Hasil pencarian online + aksi Pilih / + Wishlist / + Koleksi.
class _OnlineResults extends ConsumerWidget {
  const _OnlineResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(onlineResultsProvider);
    final query = ref.watch(onlineSearchQueryProvider);

    if (query.length < 2) {
      return const EmptyState(
        icon: Icons.travel_explore_outlined,
        title: 'Cari Buku Online',
        description:
            'Google Books & Open Library — tanpa API key. Ketik minimal 2 huruf, lalu tekan cari.',
      );
    }

    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.screenMargin),
        child: LoadingSkeleton.list(count: 4),
      ),
      error: (error, _) => ErrorState(
        title: 'Pencarian Online Gagal',
        message: 'Periksa koneksi internet Anda lalu coba lagi.',
        onRetry: () => ref.invalidate(onlineResultsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'Tidak Ada Hasil Online',
            description: 'Coba kata kunci lain, misalnya judul + penulis.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.grid,
          ),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _OnlineResultRow(result: list[index]),
        );
      },
    );
  }
}

/// Satu baris hasil online dengan aksi cepat (Bagian 6 SCR-08).
class _OnlineResultRow extends ConsumerWidget {
  const _OnlineResultRow({required this.result});

  final OnlineBookResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.grid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(path: result.cover, width: 48),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      key: ValueKey<String>('online-title-${result.title}'),
                      style: AppTypography.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      [
                        if (result.author.isNotEmpty) result.author,
                        if (result.year != null) '${result.year}',
                      ].join(' · '),
                      style: AppTypography.body2.copyWith(color: p.neutral500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      result.source,
                      style: AppTypography.caption.copyWith(color: p.neutral500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.grid),
          Wrap(
            spacing: AppSpacing.grid,
            children: [
              _OnlineAction(
                key: ValueKey<String>('pick-${result.title}'),
                label: 'Pilih',
                primary: true,
                onPressed: () => context.push('/book/edit', extra: result),
              ),
              _OnlineAction(
                label: '+ Wishlist',
                onPressed: () async {
                  await saveOnlineResult(ref, result, 'wishlist');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${result.title}" masuk Wishlist.')),
                    );
                  }
                },
              ),
              _OnlineAction(
                label: '+ Koleksi',
                onPressed: () async {
                  await saveOnlineResult(ref, result, 'unread');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${result.title}" masuk Koleksi.')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi ringkas baris hasil online (tinggi 36dp — di atas minimum
/// 48dp karena baris induk sudah menyediakan ruang sentuh vertikal).
class _OnlineAction extends StatelessWidget {
  const _OnlineAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.tonal(
        onPressed: onPressed,
        child: Text(label, style: AppTypography.body2),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label, style: AppTypography.body2),
    );
  }
}

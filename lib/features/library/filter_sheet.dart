import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/book_status.dart';
import '../../core/widgets/buttons.dart';
import 'library_data.dart';

/// Bottom sheet filter & sort SCR-08 (Bagian 6): Genre, Status, Rating,
/// Tahun terbit, Urutkan, dan tombol Reset. Dipakai bersama SCR-03.
///
/// Mengembalikan salinan filter hasil suntingan; batal = filter lama.
Future<LibraryFilter?> showLibraryFilterSheet(
  BuildContext context,
  LibraryFilter current,
) =>
    showModalBottomSheet<LibraryFilter>(
      context: context,
      // Root navigator: sheet menutupi bottom nav (Zona 4), bukan
      // tersembunyi di baliknya.
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (_) => _FilterSheet(initial: current),
    );

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final LibraryFilter initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late LibraryFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final genres = ref.watch(libraryGenresProvider).value ?? const <String>[];
    final years = ref.watch(libraryYearsProvider).value ?? const <int>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter & Urutkan', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.cardGap),

            _label('Genre'),
            _chipRow(
              children: [
                for (final genre in genres)
                  ChoiceChip(
                    label: Text(genre),
                    selected: _draft.genre == genre,
                    onSelected: (_) => setState(
                      () => _draft = _draft.genre == genre
                          ? _draft.copyWith(clearGenre: true)
                          : _draft.copyWith(genre: genre),
                    ),
                  ),
              ],
              emptyHint: 'Belum ada genre pada koleksi.',
            ),
            const SizedBox(height: AppSpacing.cardGap),

            _label('Status'),
            _chipRow(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _draft.status == null,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(clearStatus: true),
                  ),
                ),
                for (final status in BookStatus.values)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _draft.status == status.code,
                    onSelected: (_) => setState(
                      () => _draft = _draft.status == status.code
                          ? _draft.copyWith(clearStatus: true)
                          : _draft.copyWith(status: status.code),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),

            _label('Rating minimal'),
            _chipRow(
              children: [
                for (final min in const <double?>[null, 3, 4, 5])
                  ChoiceChip(
                    label: Text(min == null ? 'Semua' : '${min.toStringAsFixed(0)}+'),
                    selected: _draft.minRating == min,
                    onSelected: (_) => setState(
                      () => _draft = min == null
                          ? _draft.copyWith(clearMinRating: true)
                          : _draft.copyWith(minRating: min),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),

            _label('Tahun terbit'),
            _chipRow(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _draft.year == null,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(clearYear: true),
                  ),
                ),
                for (final year in years)
                  ChoiceChip(
                    label: Text('$year'),
                    selected: _draft.year == year,
                    onSelected: (_) => setState(
                      () => _draft = _draft.year == year
                          ? _draft.copyWith(clearYear: true)
                          : _draft.copyWith(year: year),
                    ),
                  ),
              ],
              emptyHint: 'Belum ada data tahun.',
            ),
            const SizedBox(height: AppSpacing.cardGap),

            _label('Urutkan'),
            _chipRow(
              children: [
                for (final sort in LibrarySort.values)
                  ChoiceChip(
                    label: Text(sort.label),
                    selected: _draft.sort == sort,
                    onSelected: (_) =>
                        setState(() => _draft = _draft.copyWith(sort: sort)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.screenMargin),

            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Reset',
                    onPressed: () => setState(() => _draft = _draft.reset()),
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  child: PrimaryButton(
                    key: const ValueKey<String>('apply-filter'),
                    label: 'Terapkan',
                    onPressed: () => Navigator.pop(context, _draft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              'Hasil disimpan lokal — fitur tetap berjalan saat offline.',
              style: AppTypography.caption.copyWith(color: p.neutral500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    final p = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.grid),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(
          color: p.neutral500,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _chipRow({required List<Widget> children, String? emptyHint}) {
    if (children.isEmpty) {
      final p = AppColors.of(context);
      return Text(
        emptyHint ?? '—',
        style: AppTypography.body2.copyWith(color: p.neutral500),
      );
    }
    return Wrap(spacing: AppSpacing.grid, runSpacing: AppSpacing.grid, children: children);
  }
}

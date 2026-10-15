import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/book_repository.dart';
import '../../core/db/note_quote_repository.dart';
import '../../core/models/book.dart';
import '../../core/models/note_quote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/book_status.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../home/home_data.dart';
import '../library/book_tile.dart';
import '../library/library_data.dart';
import 'book_ai_card.dart';
import 'book_detail_data.dart';
import 'completion.dart';

/// Teks sekunder (warna `neutral-500`) tanpa nilai hard-coded.
Color _muted(BuildContext context) => AppColors.of(context).neutral500;

/// SCR-06 — Detail Buku & Blockchain Proof-of-Reading
/// (F-10, F-19; bagian blockchain dibuat modul WF-08).
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, this.bookId});

  /// ID buku dari rute `/book/:id`.
  final String? bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(bookId ?? '');
    final data = id == null
        ? const AsyncValue<BookDetailData?>.error(
            'Buku tidak valid',
            StackTrace.empty,
          )
        : ref.watch(bookDetailProvider(id));

    return Scaffold(
      appBar: StorylokaTopBar(
        title: 'Detail Buku',
        showBack: true,
        actions: [if (data.value != null) _OverflowMenu(book: data.value!.book)],
      ),
      body: data.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.screenMargin),
          child: LoadingSkeleton.list(count: 3),
        ),
        error: (error, _) => ErrorState(
          message: 'Buku tidak ditemukan atau gagal dimuat.',
          onRetry:
              id == null ? null : () => ref.invalidate(bookDetailProvider(id)),
        ),
        data: (detail) => detail == null
            ? const ErrorState(message: 'Buku tidak ditemukan.')
            : _DetailBody(id: id!, detail: detail),
      ),
    );
  }
}

/// Menu ⋮ (maks 2 aksi di top bar tidak berlaku untuk menu melimpah).
class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const ValueKey<String>('detail-overflow'),
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit Buku')),
        PopupMenuItem(value: 'status', child: Text('Ubah Status')),
        PopupMenuItem(value: 'delete', child: Text('Hapus Buku')),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        context.push('/book/edit?id=${book.id}');
      case 'status':
        final next = await showModalBottomSheet<BookStatus>(
          context: context,
          // Root navigator agar sheet selalu berada di atas layer bawah.
          useRootNavigator: true,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
          ),
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('Ubah status buku', style: AppTypography.h3),
                ),
                for (final status in BookStatus.values)
                  ListTile(
                    title: Text(status.label),
                    onTap: () => Navigator.pop(sheetContext, status),
                  ),
              ],
            ),
          ),
        );
        if (next == null || !context.mounted) return;
        if (next == BookStatus.completed) {
          // Menandai selesai = wajib ulasan & rating (workflow §3.3).
          await markBookCompleted(context, ref, book);
        } else {
          final repo = await ref.read(bookRepositoryProvider.future);
          await repo?.update(book.copyWith(status: next.code));
          ref.invalidate(libraryBooksProvider);
          ref.invalidate(homeDataProvider);
        }
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
        if (confirmed != true || !context.mounted) return;
        final repo = await ref.read(bookRepositoryProvider.future);
        await repo?.softDelete(book.id!);
        ref.invalidate(libraryBooksProvider);
        ref.invalidate(homeDataProvider);
        if (context.mounted) context.pop();
    }
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.id, required this.detail});

  final int id;
  final BookDetailData detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = detail.book;
    final status = BookStatus.fromCode(book.status);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        // ---- Info utama ------------------------------------------------
        StorylokaCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(path: book.cover, width: 110),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: AppTypography.h2),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      [
                        if (book.author.isNotEmpty) book.author,
                        if (book.year != null) '${book.year}',
                      ].join(' · '),
                      style: AppTypography.body2.copyWith(color: _muted(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      [
                        if (book.genre != null) book.genre!,
                        if (book.pages != null) '${book.pages} hal',
                      ].join(' · '),
                      style: AppTypography.body2.copyWith(color: _muted(context)),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Row(
                      children: [
                        RatingStars(rating: book.rating),
                        const SizedBox(width: AppSpacing.grid),
                        StatusBadge(status: status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Progres, total jam, streak, Mulai Baca --------------------
        StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Progres Membaca', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.grid),
              ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  key: const ValueKey<String>('book-progress'),
                  value: detail.progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: AppSpacing.grid),
              Text(
                book.pages == null
                    ? 'Halaman terakhir: ${detail.lastPage}'
                    : '${(detail.progress * 100).round()}% · halaman '
                        '${detail.lastPage} dari ${book.pages}',
                style: AppTypography.body2.copyWith(color: _muted(context)),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Wrap(
                spacing: AppSpacing.grid,
                children: [
                  _StatChip(
                    icon: Icons.timer_outlined,
                    label: '${detail.hoursRead} jam total',
                  ),
                  _StatChip(
                    icon: Icons.local_fire_department_outlined,
                    label: '${detail.streakDays} hari streak',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              PrimaryButton(
                key: const ValueKey<String>('start-reading'),
                label: 'Mulai Baca',
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.push('/session?id=$id'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Sinopsis --------------------------------------------------
        if (book.synopsis != null && book.synopsis!.isNotEmpty) ...[
          StorylokaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sinopsis', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.grid),
                Text(book.synopsis!, style: AppTypography.body1),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],

        // ---- Catatan & Kutipan ----------------------------------------
        StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Catatan & Kutipan', style: AppTypography.h3),
                  ),
                  TextButton.icon(
                    key: const ValueKey<String>('add-note'),
                    onPressed: () => _showAddNoteDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              if (detail.notes.isEmpty)
                Text(
                  'Belum ada catatan. Catat kutipan favoritmu saat membaca.',
                  style: AppTypography.body2.copyWith(color: _muted(context)),
                )
              else
                for (final note in detail.notes) _NoteTile(note: note),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Ulasan & Rating -------------------------------------------
        StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ulasan & Rating', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.grid),
              if (detail.reviews.isEmpty)
                Text(
                  'Belum ada ulasan. Buku yang selesai wajib diulas.',
                  style: AppTypography.body2.copyWith(color: _muted(context)),
                )
              else
                for (final review in detail.reviews) ...[
                  Row(
                    children: [
                      RatingStars(rating: review.rating, size: 16),
                      const SizedBox(width: AppSpacing.micro),
                      Text(
                        _formatTanggalSingkat(review.createdAt),
                        style: AppTypography.caption
                            .copyWith(color: _muted(context)),
                      ),
                    ],
                  ),
                  if (review.text != null) ...[
                    const SizedBox(height: AppSpacing.micro),
                    Text(review.text!, style: AppTypography.body1),
                  ],
                  const SizedBox(height: AppSpacing.cardGap),
                ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- AI (WF-07) & Blockchain (WF-08) ---------------------------
        BookAiCard(detail: detail),
        if (status == BookStatus.completed) ...[
          const SizedBox(height: AppSpacing.cardGap),
          const _ModulePlaceholder(
            icon: Icons.link_outlined,
            title: '🔗 Terverifikasi (Hash Chain Lokal)',
            description:
                'Kartu blockchain & Validasi Rantai dibuat pada modul WF-08 '
                'dari ulasan buku ini.',
          ),
        ],
        const SizedBox(height: AppSpacing.screenMargin),
      ],
    );
  }

  Future<void> _showAddNoteDialog(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AddNoteDialog(bookId: id),
    );
    if (saved != true) return;
    ref.invalidate(bookDetailProvider(id));
  }
}

/// Dialog tambah catatan/kutipan; disimpan ke tabel `notes_quotes`.
class _AddNoteDialog extends ConsumerStatefulWidget {
  const _AddNoteDialog({required this.bookId});

  final int bookId;

  @override
  ConsumerState<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends ConsumerState<_AddNoteDialog> {
  final _controller = TextEditingController();
  String _type = 'note';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repo = await ref.read(noteQuoteRepositoryProvider.future);
    await repo?.insert(
      NoteQuote(
        bookId: widget.bookId,
        type: _type,
        content: text,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Catatan / Kutipan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'note', label: Text('Catatan')),
              ButtonSegment(value: 'quote', label: Text('Kutipan')),
            ],
            selected: <String>{_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          TextField(
            key: const ValueKey<String>('note-field'),
            controller: _controller,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Tulis di sini…'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          key: const ValueKey<String>('save-note'),
          onPressed: _controller.text.trim().isEmpty || _saving ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

/// Chip statistik kecil (ikon + teks).
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.grid,
        vertical: AppSpacing.micro + 2,
      ),
      decoration: BoxDecoration(
        color: p.neutral100,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.primary500),
          const SizedBox(width: AppSpacing.micro),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final NoteQuote note;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isQuote = note.type == 'quote';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.grid),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isQuote ? Icons.format_quote : Icons.notes,
            size: 16,
            color: p.secondary500,
          ),
          const SizedBox(width: AppSpacing.grid),
          Expanded(
            child: Text(
              isQuote ? '"${note.content}"' : note.content,
              style: AppTypography.body1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder layar modul berikutnya (WF-07 AI / WF-08 blockchain).
class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return StorylokaCard(
      color: p.neutral100,
      child: Row(
        children: [
          Icon(icon, color: p.secondary500),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.micro),
                Text(description, style: AppTypography.body2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "12 Okt 2026" — tanggal ringkas ulasan.
String _formatTanggalSingkat(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  const bulan = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}

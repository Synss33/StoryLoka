import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/book_repository.dart';
import '../../core/db/reading_session_repository.dart';
import '../../core/models/book.dart';
import '../../core/models/reading_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../book_detail/book_detail_data.dart';
import '../book_detail/completion.dart';
import '../home/home_data.dart';
import '../library/library_data.dart';
import 'session_timer.dart';

/// Provider buku untuk sesi baca (rute `/session?id=`).
final sessionBookProvider = FutureProvider.autoDispose.family<Book?, int>(
  (ref, id) async {
    final repo = await ref.watch(bookRepositoryProvider.future);
    return repo?.get(id);
  },
);

/// SCR-15 — Sesi Membaca (Stopwatch) (F-19, WF-05).
///
/// Stopwatch berbasis timestamp (akurat di latar belakang — TC-15),
/// input halaman terakhir + catatan cepat, dan penyimpanan sesi yang
/// memperbarui progres/total jam/streak; halaman = total → dialog
/// tandai selesai dengan ulasan wajib (TC-16).
class ReadingSessionScreen extends ConsumerStatefulWidget {
  const ReadingSessionScreen({super.key, this.bookId});

  final int? bookId;

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen> {
  late final SessionTimer _timer;
  Timer? _ticker;

  int _lastPage = 0;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timer = SessionTimer(startTs: DateTime.now().millisecondsSinceEpoch);
    // Tampilan stopwatch diperbarui tiap detik; durasi disimpan tetap
    // dihitung dari timestamp, bukan dari nilai tampilan ini.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_timer.isPaused) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.bookId == null
        ? const AsyncValue<Book?>.error('Buku tidak valid', StackTrace.empty)
        : ref.watch(sessionBookProvider(widget.bookId!));
    final stats = ref.watch(homeDataProvider).value?.stats;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Keluar tanpa menyimpan?'),
            content: const Text(
              'Durasi sesi ini tidak akan dicatat. '
              'Tetap simpan sesi terlebih dahulu bila ingin progres tercatat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              TextButton(
                key: const ValueKey<String>('confirm-leave-session'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: const StorylokaTopBar(title: 'Sesi Membaca', showBack: true),
        body: book.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.screenMargin),
            child: LoadingSkeleton.list(count: 2),
          ),
          error: (error, _) => ErrorState(
            message: 'Buku tidak ditemukan untuk sesi membaca.',
            onRetry: widget.bookId == null
                ? null
                : () => ref.invalidate(sessionBookProvider(widget.bookId!)),
          ),
          data: (value) => value == null
              ? const ErrorState(message: 'Buku tidak ditemukan.')
              : _SessionBody(
                  book: value,
                  timer: _timer,
                  lastPage: _lastPage,
                  note: _note,
                  monthlyLabel: stats == null
                      ? null
                      : 'Target bulan ini: '
                          '${stats.monthlyDone}/${stats.monthlyTarget} buku',
                  onLastPageChanged: (page) =>
                      setState(() => _lastPage = page),
                  onPause: () {
                    _timer.pause(DateTime.now().millisecondsSinceEpoch);
                    setState(() {});
                  },
                  onResume: () {
                    _timer.resume(DateTime.now().millisecondsSinceEpoch);
                    setState(() {});
                  },
                  saving: _saving,
                  onSave: () => _save(value),
                ),
        ),
      ),
    );
  }

  /// Simpan sesi → tabel `reading_sessions` + perbarui buku; halaman
  /// tembus total → dialog tandai selesai (ulasan wajib).
  Future<void> _save(Book book) async {
    if (_saving) return;
    setState(() => _saving = true);

    final pages = book.pages;
    final lastPage = pages == null
        ? _lastPage
        : _lastPage.clamp(0, pages);
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationSec = _timer.durationSec(now);

    final sessionRepo = await ref.read(readingSessionRepositoryProvider.future);
    final bookRepo = await ref.read(bookRepositoryProvider.future);

    final noteText = _note.text.trim();
    await sessionRepo?.insert(
      ReadingSession(
        bookId: book.id!,
        startTs: _timer.startTs,
        durationSec: durationSec,
        lastPage: lastPage > 0 ? lastPage : null,
        note: noteText.isEmpty ? null : noteText,
        updatedAt: now,
      ),
    );

    // Buku masuk status "Sedang Dibaca" (mulai dibaca → progres terpantau).
    final reachedTotal = pages != null && pages > 0 && lastPage >= pages;
    await bookRepo?.update(
      book.copyWith(
        status: reachedTotal ? book.status : 'reading',
        startedAt: book.startedAt ?? _timer.startTs,
        updatedAt: now,
      ),
    );

    ref.invalidate(homeDataProvider);
    ref.invalidate(libraryBooksProvider);
    if (book.id != null) ref.invalidate(bookDetailProvider(book.id!));

    if (!mounted) return;
    if (reachedTotal) {
      // TC-16: dialog "Tandai selesai?" → ulasan & rating wajib.
      await markBookCompleted(context, ref, book);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sesi tersimpan (${SessionTimer.format(durationSec * 1000)}).',
        ),
      ),
    );
    context.pop();
  }
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.book,
    required this.timer,
    required this.lastPage,
    required this.note,
    required this.onLastPageChanged,
    required this.onPause,
    required this.onResume,
    required this.onSave,
    required this.saving,
    this.monthlyLabel,
  });

  final Book book;
  final SessionTimer timer;
  final int lastPage;
  final TextEditingController note;
  final ValueChanged<int> onLastPageChanged;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSave;
  final bool saving;
  final String? monthlyLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final pages = book.pages;
    final elapsed = timer.elapsedMs(DateTime.now().millisecondsSinceEpoch);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        // ---- Buku yang sedang dibaca ------------------------------------
        StorylokaCard(
          child: Row(
            children: [
              BookCover(path: book.cover, width: 56),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: AppTypography.h3, maxLines: 2),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      book.author,
                      style: AppTypography.body2.copyWith(color: p.neutral500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Stopwatch (angka 40sp monospace — Bagian 1.2) --------------
        StorylokaCard(
          child: Column(
            children: [
              Text(
                key: const ValueKey<String>('stopwatch'),
                SessionTimer.format(elapsed),
                style: AppTypography.stopwatch.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'WAKTU MEMBACA',
                style: AppTypography.caption.copyWith(color: p.neutral500),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      key: const ValueKey<String>('pause-session'),
                      label: 'Jeda',
                      icon: Icons.pause_rounded,
                      onPressed: timer.isPaused ? null : onPause,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: PrimaryButton(
                      key: const ValueKey<String>('resume-session'),
                      label: 'Lanjut',
                      icon: Icons.play_arrow_rounded,
                      onPressed: timer.isPaused ? onResume : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Halaman terakhir -------------------------------------------
        StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halaman terakhir', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.grid),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey<String>('page-minus'),
                    onPressed: lastPage <= 0
                        ? null
                        : () => onLastPageChanged(lastPage - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Text(
                      '$lastPage',
                      key: const ValueKey<String>('page-value'),
                      textAlign: TextAlign.center,
                      style: AppTypography.h2,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('page-plus'),
                    onPressed: pages != null && lastPage >= pages
                        ? null
                        : () => onLastPageChanged(lastPage + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Text(
                    pages == null ? '' : '/ $pages hal',
                    style: AppTypography.body2.copyWith(color: p.neutral500),
                  ),
                ],
              ),
              if (monthlyLabel != null) ...[
                const SizedBox(height: AppSpacing.grid),
                Text(
                  monthlyLabel!,
                  style: AppTypography.body2.copyWith(color: p.neutral500),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Catatan cepat ----------------------------------------------
        StorylokaCard(
          child: TextField(
            key: const ValueKey<String>('session-note'),
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan / kutipan cepat (opsional)',
              hintText: 'mis. Halaman 45: ide tentang kebiasaan kecil…',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.screenMargin),

        PrimaryButton(
          key: const ValueKey<String>('save-session'),
          label: 'SELESAI & SIMPAN SESI',
          loading: saving,
          onPressed: onSave,
        ),
      ],
    );
  }
}

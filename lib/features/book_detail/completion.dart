import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/blockchain/hash_chain.dart';
import '../../core/db/book_repository.dart';
import '../../core/db/block_repository.dart';
import '../../core/db/review_repository.dart';
import '../../core/models/book.dart';
import '../../core/models/review.dart';
import '../../core/notifications/notification_coordinator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../home/home_data.dart';
import '../library/library_data.dart';
import 'book_detail_data.dart';

/// Menandai buku **Selesai** — workflow Bagian 3.3:
/// dialog konfirmasi → wajib ulasan & rating → status `completed` +
/// `finished_at` → tabel `reviews` → **blok hash chain** (WF-08) +
/// notifikasi "Sertifikat diterbitkan".
///
/// Mengembalikan `true` bila buku berhasil ditandai selesai.
Future<bool> markBookCompleted(
  BuildContext context,
  WidgetRef ref,
  Book book,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Tandai selesai?'),
      content: const Text(
        'Buku ini akan berstatus Selesai dan masuk sertifikat bacaan. '
        'Anda perlu mengisi ulasan & rating terlebih dahulu.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        TextButton(
          key: const ValueKey<String>('confirm-complete'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ya, Tandai Selesai'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _ReviewDialog(book: book),
  );
  if (saved != true) return false;

  // Segarkan ringkasan Beranda, daftar Library, dan detail buku
  // (kartu blockchain SCR-08 baru muncul setelah blok dibuat).
  ref.invalidate(libraryBooksProvider);
  ref.invalidate(homeDataProvider);
  if (book.id != null) ref.invalidate(bookDetailProvider(book.id!));
  return true;
}

/// Dialog wajib ulasan & rating (TC-16): batal = buku tidak ditandai selesai.
class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.book});

  final Book book;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _text = TextEditingController();
  double? _rating;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_rating == null) {
      setState(() => _error = 'Pilih rating bintang 1–5.');
      return;
    }
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Ulasan wajib diisi.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    final bookRepo = await ref.read(bookRepositoryProvider.future);
    final reviewRepo = await ref.read(reviewRepositoryProvider.future);

    await reviewRepo?.insert(
      Review(
        bookId: widget.book.id!,
        rating: _rating!,
        text: _text.text.trim(),
        createdAt: now,
      ),
    );
    await bookRepo?.update(
      widget.book.copyWith(
        status: 'completed',
        rating: _rating,
        finishedAt: now,
        updatedAt: now,
      ),
    );

    // WF-08: buat blok hash chain "Proof of Reading" dari ulasan
    // (Bagian 5.7) — `previous_hash` = hash blok terakhir pengguna,
    // atau 64 nol bila ini blok pertama (genesis).
    final reviewText = _text.text.trim();
    final blockRepo = await ref.read(blockRepositoryProvider.future);
    final userId = widget.book.userId;
    if (blockRepo != null) {
      final last = await blockRepo.lastByUser(userId);
      final block = HashChain.buildBlock(
        idx: (last?.idx ?? -1) + 1,
        userId: userId,
        bookId: widget.book.id!,
        reviewText: reviewText,
        finishedDate: now,
        previousHash: last?.hash ?? HashChain.genesisPreviousHash,
        timestamp: now,
      );
      await blockRepo.append(block);
    }

    // Notifikasi "Sertifikat diterbitkan" → riwayat SCR-14 + ketuk buka SCR-06.
    await ref.read(notificationCoordinatorProvider).emitEvent(
          userId: userId,
          type: 'certificate',
          title: 'Sertifikat Diterbitkan',
          body: '"${widget.book.title}" selesai dibaca — sertifikat bacaan '
              '(bukti Proof of Reading) sudah tersimpan.',
          route: '/book/${widget.book.id}',
          dedupePerDay: false,
        );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return AlertDialog(
      title: const Text('Ulasan & Rating'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.title, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.cardGap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    key: ValueKey<String>('star-$star'),
                    onPressed: () => setState(() => _rating = star.toDouble()),
                    icon: Icon(
                      (_rating ?? 0) >= star
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: (_rating ?? 0) >= star
                          ? p.warning500
                          : p.neutral500,
                      size: 32,
                    ),
                  ),
              ],
            ),
            TextField(
              key: const ValueKey<String>('review-field'),
              controller: _text,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ulasan *',
                hintText: 'Ceritakan kesanmu membaca buku ini…',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.grid),
              Text(
                _error!,
                style: AppTypography.body2.copyWith(color: p.danger500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        PrimaryButton(
          key: const ValueKey<String>('save-review'),
          label: 'Simpan & Tandai Selesai',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}

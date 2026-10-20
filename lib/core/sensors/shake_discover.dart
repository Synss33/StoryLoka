import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../db/book_repository.dart';
import '../models/book.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../widgets/buttons.dart';
import 'sensor_streams.dart';
import 'shake_detector.dart';

/// Pemicu shake: menghitung keluaran [ShakeDetector] dari stream sensor.
///
/// bernilai menaik (1, 2, 3, …) tiap shake terpicu; `ref.listen` pada
/// [ShakeDiscoverWatcher] memakai perubahan nilai ini (bukan status
/// async-nya) agar gelombang berikutnya tetap terdeteksi.
final shakeTriggerProvider = StreamProvider<int>((ref) {
  final detector = ShakeDetector();
  var fired = 0;
  return ref
      .watch(accelSampleStreamProvider)
      .map((sample) => detector.feed(sample) ? ++fired : null)
      .where((event) => event != null)
      .cast<int>();
});

/// Getar saat shake terpicu — dipisah ke provider agar pengujian TC-19 dapat
/// menyuntikkan penghitung panggilan.
final shakeHapticProvider = Provider<void Function()>((ref) {
  return HapticFeedback.mediumImpact;
});

/// Pemantau *Shake to Discover* (dokumen desain Bagian 4 / workflow 3.6).
///
/// Dibungkus di luar layar SCR-02 (`location: '/'`) dan SCR-04
/// (`location: '/explore'`). Shake hanya diproses bila:
/// * layar saat ini sesuai [location] (bukan sesi baca/kuis/layar lain),
/// * pengguna sedang mengetik (ada `EditableText` yang fokus) → diabaikan,
/// * modal belum terbuka.
///
/// Efek: haptic → modal 1 buku acak dari Wishlist (kosong → rekomendasi AI).
class ShakeDiscoverWatcher extends ConsumerStatefulWidget {
  const ShakeDiscoverWatcher({
    super.key,
    required this.location,
    required this.child,
  });

  /// Lokasi rute layar pemilik watcher (mis. `/`, `/explore`).
  final String location;

  final Widget child;

  @override
  ConsumerState<ShakeDiscoverWatcher> createState() =>
      _ShakeDiscoverWatcherState();
}

class _ShakeDiscoverWatcherState extends ConsumerState<ShakeDiscoverWatcher> {
  /// Mencegah shake kedua selagi modal masih terbuka.
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(shakeTriggerProvider, (previous, next) {
      final before = (previous?.hasValue ?? false) ? previous!.value : null;
      final after = next.hasValue ? next.value : null;
      if (after != null && after != before) unawaited(_onShake());
    });
    return widget.child;
  }

  Future<void> _onShake() async {
    if (_showing || !mounted) return;

    // Hanya layar pemilik watcher (bukan sesi baca/kuis/lain).
    final current =
        GoRouter.of(context).state.matchedLocation.split('?').first;
    if (current != widget.location) return;

    // Nonaktif saat mengetik (Bagian 4 — sensor saat input teks).
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }

    _showing = true;
    try {
      ref.read(shakeHapticProvider)();
      await _showDiscover();
    } finally {
      _showing = false;
    }
  }

  /// Mengambil buku acak dari Wishlist lalu membuka modal (workflow 3.6).
  Future<void> _showDiscover() async {
    final userId = ref.read(authControllerProvider).userId;
    final repo = await ref.read(bookRepositoryProvider.future);
    final books = (userId == null || repo == null)
        ? const <Book>[]
        : await repo.list(userId, status: 'wishlist');
    if (!mounted) return;

    final book = books.isEmpty
        ? null
        : books[DateTime.now().millisecondsSinceEpoch % books.length];

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _DiscoverDialog(book: book),
    );
  }
}

/// Modal hasil shake: 1 buku acak Wishlist, atau ajakan rekomendasi AI
/// bila wishlist kosong.
class _DiscoverDialog extends StatelessWidget {
  const _DiscoverDialog({this.book});

  final Book? book;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final title = book?.title;
    final hasBook = title != null;

    return AlertDialog(
      key: const ValueKey<String>('shake-modal'),
      title: Text(
        hasBook ? 'Shake to Discover' : 'Wishlist Masih Kosong',
        style: AppTypography.h3,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasBook ? Icons.auto_stories_outlined : Icons.auto_awesome_outlined,
            size: 36,
            color: p.primary500,
          ),
          const SizedBox(height: AppSpacing.cardGap),
          if (hasBook) ...[
            Text(
              title,
              key: const ValueKey<String>('shake-book-title'),
              style: AppTypography.body1.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              book!.author,
              style: AppTypography.body2.copyWith(color: p.neutral500),
            ),
          ] else
            Text(
              'Belum ada buku di Wishlist. Coba rekomendasi AI untuk '
              'menemukan bacaan baru.',
              style: AppTypography.body2.copyWith(color: p.neutral500),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('shake-later'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nanti'),
        ),
        PrimaryButton(
          key: const ValueKey<String>('shake-open'),
          label: hasBook ? 'Lihat Detail' : 'Buka AI',
          onPressed: () {
            Navigator.of(context).pop();
            context.push(hasBook ? '/book/${book!.id}' : '/ai');
          },
        ),
      ],
    );
  }
}

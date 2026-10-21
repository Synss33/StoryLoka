import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/ai_cache_repository.dart';
import '../../core/network/ai_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_store.dart';
import 'book_detail_data.dart';

/// Kartu ✨ AI di SCR-06 (F-11 / WF-07 — desain Bagian SCR-06):
/// "Ringkas dengan AI" (hasil di-cache lokal, label "Dihasilkan AI")
/// dan "Tanya AI" (buka SCR-05 dengan konteks buku ini).
class BookAiCard extends ConsumerStatefulWidget {
  const BookAiCard({super.key, required this.detail});

  final BookDetailData detail;

  @override
  ConsumerState<BookAiCard> createState() => _BookAiCardState();
}

class _BookAiCardState extends ConsumerState<BookAiCard> {
  String? _summary;
  bool _loading = false;
  String? _error;
  VoidCallback? _retry;

  BookDetailData get detail => widget.detail;
  int get _bookId => detail.book.id ?? 0;

  String get _cacheKey => 'summary:$_bookId';

  /// Ringkas dengan AI: pakai cache bila ada → kalau tidak panggil backend →
  /// simpan ke `ai_cache` → tampilkan + label "Dihasilkan AI" (TC-24).
  Future<void> _summarize({bool fromCache = true}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _retry = null;
    });

    // 1. Cache lokal (Bagian 5.6 — "hasil ringkasan di-cache lokal").
    if (fromCache) {
      final cache = await ref.read(aiCacheRepositoryProvider.future);
      final cached = await cache?.read(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _summary = cached;
          _loading = false;
        });
        return;
      }
    }

    // 2. Panggil proxy AI (token sesi server; API key tetap di server).
    final token = await onlineTokenOf(ref.read(authStoreProvider));
    final notes = detail.notes.take(5).map((n) => n.content).toList();
    final result = await ref.read(aiServiceProvider).summarize(
          title: detail.book.title,
          author: detail.book.author,
          synopsis: detail.book.synopsis,
          notes: notes,
          token: token,
        );
    if (!mounted) return;

    if (result.ok) {
      final text = result.text!;
      // 3. Simpan ke cache (best-effort — gagal tidak menghalangi tampil).
      final cache = await ref.read(aiCacheRepositoryProvider.future);
      final userId = ref.read(authControllerProvider).userId ?? detail.book.userId;
      if (cache != null) {
        try {
          await cache.save(userId: userId, key: _cacheKey, content: text);
        } catch (_) {}
      }
      setState(() {
        _summary = text;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = false;
      if (result.failure == AiFailure.offline) {
        _error = 'Offline — ringkasan tersimpan tampil saat kembali online.';
      } else {
        _error = result.message;
      }
      _retry = () => _summarize(fromCache: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return StorylokaCard(
      color: colors.neutral100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: colors.secondary500),
              const SizedBox(width: AppSpacing.micro),
              Text('✨ AI', style: AppTypography.h3),
            ],
          ),
          const SizedBox(height: AppSpacing.grid),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey<String>('ai-summarize'),
                  label: 'Ringkas dengan AI',
                  onPressed: _loading ? null : () => _summarize(),
                ),
              ),
              const SizedBox(width: AppSpacing.grid),
              Expanded(
                child: SecondaryButton(
                  key: const ValueKey<String>('ai-tanya'),
                  label: 'Tanya AI',
                  onPressed: () => context.push('/ai?book=$_bookId'),
                ),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: AppSpacing.grid),
            const LinearProgressIndicator(key: ValueKey<String>('ai-loading')),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.grid),
            Text(
              _error!,
              key: const ValueKey<String>('ai-card-error'),
              style: AppTypography.body2.copyWith(color: colors.danger500),
            ),
            if (_retry != null)
              TextButton(
                key: const ValueKey<String>('ai-card-retry'),
                onPressed: _retry,
                child: const Text('Coba Lagi'),
              ),
          ],
          if (_summary != null) ...[
            const SizedBox(height: AppSpacing.grid),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.grid),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _summary!,
                    key: const ValueKey<String>('ai-summary'),
                    style: AppTypography.body1,
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: colors.secondary500,
                      ),
                      const SizedBox(width: AppSpacing.micro),
                      Text(
                        'Dihasilkan AI',
                        key: const ValueKey<String>('ai-summary-label'),
                        style: AppTypography.caption
                            .copyWith(color: colors.neutral500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

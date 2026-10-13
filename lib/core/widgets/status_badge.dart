import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../utils/book_status.dart';

/// Badge status buku berbentuk pil — dokumen desain Bagian 8 & 7.
///
/// Warna mengikuti model status:
/// `wishlist` → warning-500, `unread` → neutral-500,
/// `reading` → primary-500, `completed` → success-500.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final BookStatus status;

  /// Label alternatif; default memakai [BookStatus.label].
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final color = switch (status) {
      BookStatus.wishlist => p.warning500,
      BookStatus.unread => p.neutral500,
      BookStatus.reading => p.primary500,
      BookStatus.completed => p.success500,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.grid,
        vertical: AppSpacing.micro + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label ?? status.label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}

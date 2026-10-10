import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// State kosong — dokumen desain SCR-12: ilustrasi lembut, judul,
/// deskripsi, dan CTA. Variasi (Wishlist, hasil cari, notifikasi,
/// riwayat sesi) cukup membedakan [title]/[description]/[actionLabel].
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final IconData icon;

  /// Label CTA, mis. `Cari Buku` / `Tambah Buku Baru`.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustrasi lembut: lingkaran lembut + ikon.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: p.primary50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: p.primary500),
            ),
            const SizedBox(height: AppSpacing.screenMargin),
            Text(
              title,
              style: AppTypography.h2.copyWith(color: p.textPrimary),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.grid),
              Text(
                description!,
                style: AppTypography.body1.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.screenMargin),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: PrimaryButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

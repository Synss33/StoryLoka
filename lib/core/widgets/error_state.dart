import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

/// State error & offline — dokumen desain SCR-13: ikon `danger-500`,
/// pesan (“Koneksi Terputus” / “Gagal Memuat Data”), dan CTA
/// `Coba Lagi` dengan indikator loading.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.title = 'Gagal Memuat Data',
    this.icon = Icons.cloud_off_outlined,
    this.onRetry,
    this.retrying = false,
  });

  final String title;
  final String message;
  final IconData icon;

  /// CTA `Coba Lagi`; `null` → tombol tidak ditampilkan.
  final VoidCallback? onRetry;

  /// Saat `true`, tombol menampilkan spinner dan nonaktif.
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: p.danger500),
            const SizedBox(height: AppSpacing.cardGap),
            Text(
              title,
              style: AppTypography.h3.copyWith(color: p.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.grid),
            Text(
              message,
              style: AppTypography.body1.copyWith(color: p.neutral500),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.screenMargin),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: PrimaryButton(
                  label: 'Coba Lagi',
                  onPressed: onRetry,
                  loading: retrying,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

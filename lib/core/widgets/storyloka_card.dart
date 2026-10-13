import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Kartu dasar Storyloka — dokumen desain Bagian 8.
///
/// `surface`, radius 12, padding 16; mode terang memakai bayangan
/// `0 2 8 rgba(15,23,42,0.06)`, mode gelap tanpa bayangan dan
/// memakai border `neutral-200` (Bagian 1.3). Semua kelompok data
/// pada layar wajib dibungkus widget ini (Master Layout Zona 2).
class StorylokaCard extends StatelessWidget {
  const StorylokaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color,
  });

  final Widget child;

  /// Jika diisi, kartu dapat ditukar (ketuk) dengan efek ripple.
  final VoidCallback? onTap;

  final EdgeInsetsGeometry padding;

  /// Warna latar; default `surface` dari palet aktif.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final isDark = p.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: AppRadius.mediumAll,
        border: isDark ? Border.all(color: p.neutral200) : null,
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: p.cardShadow,
                  offset: AppLayout.cardShadowOffset,
                  blurRadius: AppLayout.cardShadowBlur,
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mediumAll,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/theme/app_colors.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/core/theme/app_typography.dart';

/// Uji design tokens: ThemeData terang/gelap wajib memakai nilai token
/// dari dokumen desain Bagian 1 (tanpa warna/ukuran hard-coded di luar
/// `lib/core/theme`).
void main() {
  test('tema terang memakai token mode Light', () {
    final theme = AppTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.light.primary500);
    expect(theme.colorScheme.surface, AppColors.light.surface);
    expect(theme.colorScheme.error, AppColors.light.danger500);
    expect(theme.scaffoldBackgroundColor, AppColors.light.bg);
    expect(theme.textTheme.titleLarge?.fontSize, AppTypography.h1.fontSize);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
  });

  test('tema gelap memakai token mode Dark', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.dark.primary500);
    expect(theme.colorScheme.surface, AppColors.dark.surface);
    expect(theme.colorScheme.error, AppColors.dark.danger500);
    expect(theme.scaffoldBackgroundColor, AppColors.dark.bg);
    expect(theme.textTheme.bodyMedium?.fontSize, AppTypography.body1.fontSize);
  });

  test('tipografi memuat keluarga Inter dengan line height dokumen desain',
      () {
    expect(AppTypography.h1.height, closeTo(32 / 24, 0.001));
    expect(AppTypography.h2.height, closeTo(24 / 18, 0.001));
    expect(AppTypography.h3.height, closeTo(20 / 15, 0.001));
    expect(AppTypography.body1.height, closeTo(20 / 14, 0.001));
    expect(AppTypography.body2.height, closeTo(16 / 12, 0.001));
    expect(AppTypography.caption.height, closeTo(14 / 11, 0.001));
    expect(AppTypography.stopwatch.fontSize, 40);
    expect(
      AppTypography.stopwatch.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}

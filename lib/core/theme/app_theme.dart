import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Membangun [ThemeData] terang & gelap Storyloka dari design tokens
/// (dokumen desain Bagian 1). File ini satu-satunya tempat `ThemeData`
/// disusun; layar hanya memakai `Theme.of(context)` / [AppColors.of].
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppPalette p) {
    final colorScheme = _colorScheme(p);
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: _textTheme(p),
      scaffoldBackgroundColor: p.bg,
      splashFactory: InkSparkle.splashFactory,
      // Target sentuh bawaan Material (>= 48dp) dipertahankan.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      disabledColor: p.neutral500,
      focusColor: p.primary50,
      hoverColor: p.primary50,
      highlightColor: p.neutral100,
      dividerColor: p.neutral200,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary500,
        selectionColor: p.primary50,
        selectionHandleColor: p.primary500,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: AppLayout.topBarHeight,
        centerTitle: false,
        titleTextStyle: AppTypography.h2.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      // Semua kelompok data dibungkus StorylokaCard (Bagian 2, Zona 2).
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: p.cardShadow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumAll,
          // Mode gelap tanpa bayangan → memakai border neutral-200 (Bagian 1.3).
          side: p.brightness == Brightness.dark
              ? BorderSide(color: p.neutral200)
              : BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.largeAll),
        titleTextStyle: AppTypography.h2.copyWith(color: p.textPrimary),
        contentTextStyle: AppTypography.body1.copyWith(color: p.textPrimary),
      ),
      // PrimaryButton: tinggi 48, radius 12, label berat SemiBold (Bagian 8).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary500,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.neutral100,
          disabledForegroundColor: p.neutral500,
          minimumSize: const Size.fromHeight(AppLayout.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.grid,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
          textStyle: AppTypography.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      // SecondaryButton: outline primary-600 (Bagian 8).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary600,
          disabledForegroundColor: p.neutral500,
          minimumSize: const Size.fromHeight(AppLayout.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: AppSpacing.grid,
          ),
          side: BorderSide(color: p.primary600, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
          textStyle: AppTypography.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary600,
          disabledForegroundColor: p.neutral500,
          minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          textStyle: AppTypography.body1.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      // Input: radius 12, fokus ring primary-500 2dp, galat border
      // danger-500 + pesan 12sp (Bagian 1.4).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.neutral100,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.cardGap,
        ),
        hintStyle: AppTypography.body1.copyWith(color: p.neutral500),
        labelStyle: AppTypography.body1.copyWith(color: p.neutral500),
        errorStyle: AppTypography.body2.copyWith(color: p.danger500),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: p.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: p.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: p.primary500, width: AppLayout.focusRingWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: p.danger500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mediumAll,
          borderSide: BorderSide(color: p.danger500, width: AppLayout.focusRingWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.neutral200,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: AppTypography.body1.copyWith(color: p.bg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary500,
        unselectedItemColor: p.neutral500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary500),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.surface
              : p.neutral500,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.primary500
              : p.neutral200,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.neutral500,
        textColor: p.textPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
        ),
        minTileHeight: AppSpacing.touchTarget,
      ),
    );
  }

  /// Warna teks per slot (H1…Caption) mengikuti token teks aktif.
  static TextTheme _textTheme(AppPalette p) {
    final base = AppTypography.textTheme();
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(color: p.textPrimary),
      titleMedium: base.titleMedium?.copyWith(color: p.textPrimary),
      titleSmall: base.titleSmall?.copyWith(color: p.textPrimary),
      bodyLarge: AppTypography.body1.copyWith(color: p.textPrimary),
      bodyMedium: base.bodyMedium?.copyWith(color: p.textPrimary),
      bodySmall: base.bodySmall?.copyWith(color: p.neutral500),
      labelLarge: AppTypography.body1
          .copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
      labelMedium: AppTypography.caption.copyWith(color: p.textPrimary),
      labelSmall: base.labelSmall?.copyWith(color: p.neutral500),
    );
  }

  static ColorScheme _colorScheme(AppPalette p) {
    return ColorScheme(
      brightness: p.brightness,
      primary: p.primary500,
      onPrimary: p.onPrimary,
      secondary: p.secondary500,
      onSecondary: p.onPrimary,
      error: p.danger500,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
    ).copyWith(
      primaryContainer: p.primary50,
      onPrimaryContainer: p.primary600,
      secondaryContainer: p.primary50,
      onSecondaryContainer: p.primary600,
      errorContainer: p.danger500,
      onErrorContainer: Colors.white,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.neutral100,
      surfaceContainerHighest: p.neutral100,
      onSurfaceVariant: p.neutral500,
      outline: p.neutral200,
      outlineVariant: p.neutral200,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.bg,
      inversePrimary: p.primary600,
    );
  }
}

import 'package:flutter/material.dart';

/// Design token tipografi Storyloka — dokumen desain Bagian 1.2.
///
/// Font Inter di-bundle sebagai aset (`assets/fonts/`), tidak diunduh
/// saat runtime. Ukuran/berat/line-height TIDAK boleh ditulis di luar file ini.
abstract final class AppTypography {
  /// Nama keluarga font yang didaftarkan di pubspec.yaml.
  static const String fontFamily = 'Inter';

  /// H1 Display — 24sp / Bold / line height 32.
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
  );

  /// H2 Section — 18sp / SemiBold / line height 24.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
  );

  /// H3 Card Title — 15sp / SemiBold / line height 20.
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 20 / 15,
  );

  /// Body 1 — 14sp / Regular / line height 20.
  static const TextStyle body1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  /// Body 2 — 12sp / Regular / line height 16.
  static const TextStyle body2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  /// Caption — 11sp / Medium / line height 14.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 14 / 11,
  );

  /// Angka stopwatch — 40sp / Bold / monospace (tabular figures)
  /// agar lebar digit tidak bergeser saat berjalan.
  static const TextStyle stopwatch = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 48 / 40,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Pemetaan gaya Storyloka ke TextTheme Material agar gaya baku
  /// `Theme.of(context).textTheme` juga memakai token yang sama.
  static TextTheme textTheme() => const TextTheme(
        titleLarge: h1, // H1 Display
        titleMedium: h2, // H2 Section
        titleSmall: h3, // H3 Card Title
        bodyMedium: body1, // Body 1
        bodySmall: body2, // Body 2
        labelSmall: caption, // Caption
      );
}

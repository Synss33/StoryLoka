import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode tema Storyloka — dokumen desain Bagian 1.5:
/// **Otomatis (Sensor) · Terang · Gelap**.
enum StorylokaThemeMode {
  /// Otomatis: mengikuti sensor cahaya (WF-06); sampai sensor diaktifkan,
  /// mode ini mengikuti tema sistem perangkat.
  auto,

  /// Terang.
  terang,

  /// Gelap.
  gelap,
}

/// State pemilihan mode tema.
///
/// WF-01 hanya menyiapkan state-nya (aturan sensor di Bagian 4 menyusul
/// di modul WF-06). Penyimpanan persisten ke tabel `settings` menyusul
/// bersama WF-04.
class ThemeModeNotifier extends Notifier<StorylokaThemeMode> {
  @override
  StorylokaThemeMode build() => StorylokaThemeMode.auto;

  void set(StorylokaThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, StorylokaThemeMode>(
  ThemeModeNotifier.new,
);

/// Pemetaan ke mode Material yang dipakai `MaterialApp.themeMode`.
extension StorylokaThemeModeX on StorylokaThemeMode {
  ThemeMode get material => switch (this) {
        StorylokaThemeMode.auto => ThemeMode.system,
        StorylokaThemeMode.terang => ThemeMode.light,
        StorylokaThemeMode.gelap => ThemeMode.dark,
      };
}

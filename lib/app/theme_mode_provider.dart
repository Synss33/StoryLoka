import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/settings_repository.dart';

/// Mode tema Storyloka — dokumen desain Bagian 1.5:
/// **Otomatis (Sensor) · Terang · Gelap**.
///
/// Nilai enum menyimpan representasi kolom `settings.theme_mode`
/// (`auto`/`light`/`dark` — WF-04 mempersistensi pilihan tema).
enum StorylokaThemeMode {
  /// Otomatis: mengikuti sensor cahaya (WF-06); sampai sensor diaktifkan,
  /// mode ini mengikuti tema sistem perangkat.
  auto('auto'),

  /// Terang.
  terang('light'),

  /// Gelap.
  gelap('dark');

  const StorylokaThemeMode(this.storage);

  /// Nilai yang disimpan ke kolom `theme_mode`.
  final String storage;

  /// Memutar dari nilai kolom `theme_mode` (bila tidak dikenal → `auto`).
  static StorylokaThemeMode fromStorage(String? value) =>
      values.firstWhere((mode) => mode.storage == value,
          orElse: () => auto);
}

/// State pemilihan mode tema.
///
/// WF-01 hanya menyiapkan state-nya (aturan sensor di Bagian 4 menyusul
/// di modul WF-06); persistensi ke tabel `settings` (WF-04) dilakukan
/// lewat [ThemeModeNotifier.persist] dan dimuat saat splash.
class ThemeModeNotifier extends Notifier<StorylokaThemeMode> {
  @override
  StorylokaThemeMode build() => StorylokaThemeMode.auto;

  void set(StorylokaThemeMode mode) {
    state = mode;
  }

  /// Memuat tema tersimpan milik [userId] (dipanggil splash setelah sesi
  /// valid; kegagalan diabaikan — tema sementara tetap `auto`).
  Future<void> load(int userId) async {
    try {
      final settings = await ref.read(settingsRepositoryProvider.future);
      final row = await settings?.read(userId);
      if (row != null) state = StorylokaThemeMode.fromStorage(row.themeMode);
    } catch (_) {
      // Pengaturan belum terbaca — biarkan mode default.
    }
  }

  /// Menyimpan pilihan tema ke tabel `settings` (LWW `updated_at`).
  Future<void> persist(int userId, StorylokaThemeMode mode) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings?.setThemeMode(userId, mode.storage);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode_provider.dart';
import 'sensor_streams.dart';

/// Sensor 1 — *Auto-Theme* dari sensor cahaya (dokumen desain Bagian 4,
/// workflow 3.6):
///
/// * lux **< 15** selama ≥ 2 dtk → Dark Mode;
/// * lux **> 40** selama ≥ 2 dtk → Light Mode (histeresis — zona
///   15…40 diabaikan agar tidak berkedip);
/// * hanya aktif bila tema = **Otomatis**; mode manual mengabaikan sensor;
/// * iOS tidak punya sensor cahaya → stream kosong, tema tetap mengikuti
///   sistem (batasan platform, desain Bagian 4).
///
/// State = override tema hasil sensor (`null` = belum ada keputusan).
class AutoThemeController extends Notifier<ThemeMode?> {
  Timer? _timer;

  @override
  ThemeMode? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Memberi satu pembacaan lux dari [luxProvider].
  void feed(int lux) {
    if (ref.read(themeModeProvider) != StorylokaThemeMode.auto) return;

    final ThemeMode? target = lux < 15
        ? ThemeMode.dark
        : lux > 40
            ? ThemeMode.light
            : null;

    if (target == null || target == state) {
      // Zona mati, atau sudah sesuai → batalkan perubahan tertunda.
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      _timer = null;
      state = target;
    });
  }

  /// Membatalkan keputusan sensor (dipanggil saat pengguna memilih mode
  /// manual — sensor diabaikan).
  void reset() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }
}

final autoThemeProvider =
    NotifierProvider<AutoThemeController, ThemeMode?>(AutoThemeController.new);

/// Pembacaan lux terkini dari sensor cahaya (hanya Android —
/// `luxStreamProvider` me-return stream kosong di platform lain).
final luxProvider = StreamProvider<int>((ref) {
  return ref.watch(luxStreamProvider);
});

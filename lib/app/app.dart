import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_coordinator.dart';
import '../core/sensors/auto_theme.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';
import 'theme_mode_provider.dart';

/// Widget aplikasi Storyloka: memasang tema (terang/gelap), state mode tema,
/// dan router. Database terenkripsi dibuka sesuai kebutuhan (splash saat
/// sesi valid) dan ditutup saat logout.
///
/// Mode **Otomatis** memakai sensor cahaya (WF-06): pembacaan lux terkini
/// di-`feed`-kan ke [autoThemeProvider]; bila pengguna berpindah ke mode
/// manual, keputusan sensor di-reset (dokumen desain Bagian 4).
class StorylokaApp extends ConsumerWidget {
  const StorylokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode tema: Otomatis / Terang / Gelap (dokumen desain Bagian 1.5).
    final mode = ref.watch(themeModeProvider);
    final sensorOverride = ref.watch(autoThemeProvider);

    // Notifikasi: daftarkan callback ketuk sekali saat aplikasi berjalan
    // (F-14 — WF-06); gagal → riwayat lokal tetap berfungsi.
    unawaited(ref.read(notificationCoordinatorProvider).init());

    // Sensor cahaya → auto-theme (histeresis ≥ 2 dtk ada di controller).
    ref.listen(luxProvider, (previous, next) {
      final lux = next.hasValue ? next.value : null;
      if (lux != null && lux != previous?.value) {
        ref.read(autoThemeProvider.notifier).feed(lux);
      }
    });

    // Mode manual mengabaikan sensor → keputusan terakhir dibatalkan.
    ref.listen(themeModeProvider, (previous, next) {
      if (next != StorylokaThemeMode.auto) {
        ref.read(autoThemeProvider.notifier).reset();
      }
    });

    final themeMode = mode == StorylokaThemeMode.auto
        ? (sensorOverride ?? ThemeMode.system)
        : mode.material;

    return MaterialApp.router(
      title: 'Storyloka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}

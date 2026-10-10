import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';
import 'theme_mode_provider.dart';

/// Widget aplikasi Storyloka: memasang tema (terang/gelap), state mode tema,
/// dan router. Database terenkripsi dibuka sesuai kebutuhan (splash saat
/// sesi valid) dan ditutup saat logout.
class StorylokaApp extends ConsumerWidget {
  const StorylokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode tema: Otomatis / Terang / Gelap (dokumen desain Bagian 1.5).
    final themeMode = ref.watch(themeModeProvider).material;

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

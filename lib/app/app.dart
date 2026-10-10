import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/database_provider.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';
import 'theme_mode_provider.dart';

/// Widget aplikasi Storyloka: memasang tema (terang/gelap), state mode tema,
/// router, serta membuka database terenkripsi saat aplikasi mulai.
class StorylokaApp extends ConsumerWidget {
  const StorylokaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode tema: Otomatis / Terang / Gelap (dokumen desain Bagian 1.5).
    final themeMode = ref.watch(themeModeProvider).material;

    // Membuka SQLite terenkripsi (kunci acak 256-bit dari secure storage).
    // Gagal di platform tanpa plugin → null, aplikasi tetap berjalan.
    ref.watch(databaseProvider);

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

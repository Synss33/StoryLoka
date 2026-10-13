import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-02 — Beranda, Ringkasan & Currently Reading.
///
/// WF-01: kerangka Master Layout (Zona 1 top bar + Zona 2 konten) dengan
/// state placeholder. Isi kartu ringkasan, Currently Reading, aksi cepat,
/// dan My Collection diisi pada modul WF-05; shake sensor pada WF-06.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Halo, Pembaca'),
      body: ScreenPlaceholder(
        title: 'Belum Ada Ringkasan Bacaan',
        description:
            'Layar Beranda (SCR-02) berisi Reading Summary, Currently Reading, '
            'Aksi Cepat, dan My Collection — diisi pada modul WF-05.',
        icon: Icons.dashboard_outlined,
        footer: _ConnectionStatus(health: health, database: database),
      ),
    );
  }
}

/// Catatan kecil di bawah placeholder: status panggilan `GET /health`
/// ke backend dan status pembukaan database terenkripsi (DoD WF-01).
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.health, required this.database});

  final AsyncValue<HealthStatus> health;
  final Object? database;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final apiText = health.when(
      data: (value) => '${value.ok ? "✓" : "✗"} ${value.message}',
      error: (_, _) => '✗ Gagal memeriksa backend',
      loading: () => '• Memeriksa backend…',
    );
    final dbText = database == null
        ? '✗ Database terenkripsi belum terbuka'
        : '✓ Database terenkripsi terbuka';
    final caption = AppTypography.body2.copyWith(color: p.neutral500);

    return Column(
      children: [
        Text('API: $apiText', style: caption, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.micro),
        Text('DB : $dbText', style: caption, textAlign: TextAlign.center),
      ],
    );
  }
}

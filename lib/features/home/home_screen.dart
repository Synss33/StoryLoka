import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';
import '../profile/profile_data.dart';

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
    // Avatar di top bar SCR-02 ("Halo, [Nama]" + gambar — TC-10).
    final user = ref.watch(profileDataProvider).value?.user;

    return Scaffold(
      appBar: StorylokaTopBar(
        title: 'Halo, Pembaca',
        leading: _HomeAvatar(photoPath: user?.photoPath, name: user?.name),
      ),
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

/// Avatar profil di top bar Beranda (ketuk → SCR-09 Profil).
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({this.photoPath, this.name});

  final String? photoPath;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Profil',
      padding: EdgeInsets.zero,
      onPressed: () => context.go('/profil'),
      icon: ProfileAvatar(photoPath: photoPath, name: name, radius: 16),
    );
  }
}

/// Catatan kecil di bawah placeholder: status panggilan `GET /health`
/// ke backend dan status pembukaan database terenkripsi (DoD WF-01).
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.health, required this.database});

  final AsyncValue<HealthStatus> health;
  final AsyncValue<Object?> database;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final apiText = health.when(
      data: (value) => '${value.ok ? "✓" : "✗"} ${value.message}',
      error: (_, _) => '✗ Gagal memeriksa backend',
      loading: () => '• Memeriksa backend…',
    );
    final dbText = database.when(
      data: (db) => db == null
          ? '✗ Database terenkripsi belum terbuka'
          : '✓ Database terenkripsi terbuka',
      error: (_, _) => '✗ Database gagal dibuka',
      loading: () => '• Membuka database…',
    );
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

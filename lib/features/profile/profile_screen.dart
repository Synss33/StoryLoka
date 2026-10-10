import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-09 — Profil, Pengaturan & Keamanan.
///
/// WF-01: placeholder. Header profil berfoto, statistik, keamanan & sesi,
/// notifikasi, tema, dan sinkronisasi → modul WF-04.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Profil'),
      body: ScreenPlaceholder(
        title: 'Profil Pengguna',
        description:
            'Layar Profil (SCR-09) berisi foto profil, statistik baca, '
            'keamanan & sesi, pengaturan notifikasi, tema, dan sinkronisasi '
            '— diisi pada modul WF-04.',
        icon: Icons.person_outline,
      ),
    );
  }
}

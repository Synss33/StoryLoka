import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-14 — Pusat Notifikasi.
///
/// WF-01: placeholder + rute (nav tampil, Bagian 3.3). Daftar notifikasi
/// pengingat/target/streak/sertifikat dan penjadwalan lokal → modul WF-06.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Pusat Notifikasi'),
      body: ScreenPlaceholder(
        title: 'Belum Ada Notifikasi',
        description:
            'Layar Pusat Notifikasi (SCR-14) berisi riwayat notifikasi '
            'pengingat harian, target/streak, dan sertifikat '
            '— diisi pada modul WF-06.',
        icon: Icons.notifications_none,
      ),
    );
  }
}

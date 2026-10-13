import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-15 — Sesi Membaca (Stopwatch).
///
/// WF-01: placeholder + rute. Stopwatch berbasis timestamp (akurat di latar
/// belakang), input halaman terakhir, simpan sesi → modul WF-05.
class ReadingSessionScreen extends StatelessWidget {
  const ReadingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Sesi Membaca', showBack: true),
      body: ScreenPlaceholder(
        title: 'Sesi Membaca Belum Dimulai',
        description:
            'Layar Sesi Membaca (SCR-15) berisi stopwatch berbasis '
            'timestamp, pencatat halaman terakhir, dan tombol '
            'Selesai & Simpan Sesi — diisi pada modul WF-05.',
        icon: Icons.timer_outlined,
      ),
    );
  }
}

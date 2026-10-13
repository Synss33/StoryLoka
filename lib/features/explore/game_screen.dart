import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-16 — Permainan Book Trivia.
///
/// WF-01: placeholder + rute. 10 soal pilihan ganda, timer 15 detik,
/// skor → koin, skor tertinggi tersimpan → modul WF-09.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Book Trivia', showBack: true),
      body: ScreenPlaceholder(
        title: 'Permainan Belum Tersedia',
        description:
            'Layar Permainan (SCR-16) berisi progres soal, timer 15 detik, '
            'pilihan jawaban, dan hasil skor/koin — diisi pada modul WF-09.',
        icon: Icons.videogame_asset_outlined,
      ),
    );
  }
}

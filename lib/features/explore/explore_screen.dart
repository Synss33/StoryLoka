import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-04 — Explore: Peta (LBS), Konverter & Game.
///
/// WF-01: placeholder. Segmen Peta/LBS + shake → WF-06, Konverter mata uang
/// & waktu → WF-05, segmen Game → WF-09.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Explore'),
      body: ScreenPlaceholder(
        title: 'Jelajahi Fitur Tambahan',
        description:
            'Layar Explore (SCR-04) berisi segmen Peta (LBS), Konverter '
            'mata uang & waktu, dan Game — diisi pada modul WF-05, WF-06, '
            'dan WF-09.',
        icon: Icons.explore_outlined,
      ),
    );
  }
}

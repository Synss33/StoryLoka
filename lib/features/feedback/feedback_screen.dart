import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-10 — Saran & Kesan Mata Kuliah Pemrograman Aplikasi Mobile.
///
/// WF-01: placeholder. Dua kolom (Kesan & Saran) yang disimpan lokal dan
/// dikirim ke web service → modul WF-04.
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Kesan & Saran PAM'),
      body: ScreenPlaceholder(
        title: 'Kesan & Saran Mata Kuliah PAM',
        description:
            'Layar Kesan & Saran (SCR-10) berisi dua kolom isian untuk '
            'mata kuliah Pemrograman Aplikasi Mobile — diisi pada modul WF-04.',
        icon: Icons.forum_outlined,
      ),
    );
  }
}

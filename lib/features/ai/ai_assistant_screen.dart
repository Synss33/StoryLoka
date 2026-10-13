import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-05 — AI / LLM Assistant.
///
/// WF-01: placeholder + rute. Quick action ringkasan/rekomendasi/jelaskan,
/// chat dengan label “Dihasilkan AI”, error/timeout/kuota/offline
/// → modul WF-07 (lewat backend proxy).
class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Storyloka AI', showBack: true),
      body: ScreenPlaceholder(
        title: 'Asisten AI Belum Tersedia',
        description:
            'Layar AI Assistant (SCR-05) berisi quick action, percakapan '
            'dengan label “Dihasilkan AI”, serta penanganan offline '
            '— diisi pada modul WF-07.',
        icon: Icons.auto_awesome_outlined,
      ),
    );
  }
}

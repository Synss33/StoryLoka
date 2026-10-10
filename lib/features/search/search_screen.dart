import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-08 — Pencarian & Filter.
///
/// WF-01: placeholder + rute. Pencarian lokal & online, filter
/// genre/status/rating/tahun, sort, dan aksi pilih hasil
/// → modul WF-05.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Pencarian', showBack: true),
      body: ScreenPlaceholder(
        title: 'Belum Ada Hasil Pencarian',
        description:
            'Layar Pencarian (SCR-08) berisi kolom cari, tab Koleksi Saya/'
            'Cari Online, filter lengkap, dan aksi cepat hasil '
            '— diisi pada modul WF-05.',
        icon: Icons.search,
      ),
    );
  }
}

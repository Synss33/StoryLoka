import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-03 — Library: Koleksi & Wishlist.
///
/// WF-01: placeholder + rute. Grid 2 kolom, filter/sort, FAB Tambah Buku,
/// long-press action sheet → modul WF-05.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Library'),
      body: ScreenPlaceholder(
        title: 'Belum Ada Buku di Koleksi',
        description:
            'Layar Library (SCR-03) berisi tab Koleksi/Wishlist, pencarian '
            'singkat, filter & sort, grid cover 2:3, dan FAB Tambah Buku '
            '— diisi pada modul WF-05.',
        icon: Icons.auto_stories_outlined,
      ),
    );
  }
}

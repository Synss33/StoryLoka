import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-07 — Tambah / Edit Buku.
///
/// WF-01: placeholder + rute. Form buku, validasi, sumber manual/online,
/// dan pemindaian barcode (opsional) → modul WF-05.
class AddBookScreen extends StatelessWidget {
  const AddBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Tambah Buku', showBack: true),
      body: ScreenPlaceholder(
        title: 'Form Buku Belum Tersedia',
        description:
            'Layar Tambah/Edit Buku (SCR-07) berisi form buku dengan '
            'validasi, sumber manual atau hasil pencarian online '
            '— diisi pada modul WF-05.',
        icon: Icons.add_box_outlined,
      ),
    );
  }
}

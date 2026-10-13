import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-06 — Detail Buku & Blockchain Proof-of-Reading.
///
/// WF-01: placeholder + rute. Info buku, catatan/kutipan, ulasan, aksi AI,
/// dan kartu blockchain (hanya status Selesai) → modul WF-05 & WF-08.
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, this.bookId});

  /// ID buku dari rute `/book/:id`.
  final String? bookId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Detail Buku', showBack: true),
      body: ScreenPlaceholder(
        title: 'Detail Buku Belum Tersedia',
        description: bookId == null
            ? 'Layar Detail Buku (SCR-06) berisi info buku, catatan, '
                'ulasan, dan kartu blockchain — diisi pada modul WF-05 '
                'dan WF-08.'
            : 'Buku #$bookId — info detail, catatan, ulasan, dan kartu '
                'blockchain diisi pada modul WF-05 dan WF-08.',
        icon: Icons.book_outlined,
      ),
    );
  }
}

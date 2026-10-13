import 'package:flutter/material.dart';

import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';

/// SCR-17 — Edit Profil.
///
/// WF-01: placeholder + rute. Ganti foto (kamera/galeri), ubah nama,
/// ganti password dengan verifikasi password lama → modul WF-04.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Edit Profil', showBack: true),
      body: ScreenPlaceholder(
        title: 'Edit Profil Belum Tersedia',
        description:
            'Layar Edit Profil (SCR-17) berisi penggantian foto, perubahan '
            'nama, dan ganti password — diisi pada modul WF-04.',
        icon: Icons.manage_accounts_outlined,
      ),
    );
  }
}

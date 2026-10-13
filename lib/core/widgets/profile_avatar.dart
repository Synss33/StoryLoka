import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar profil: menampilkan foto lokal (`users.photo_path`) bila ada,
/// selain itu inisial nama (atau ikon orang). Dipakai header SCR-09 dan
/// top bar Beranda SCR-02 (TC-10: foto tampil di Profil & Beranda).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoPath,
    this.name,
    this.radius = 36,
  });

  /// Path absolut foto profil; `null`/kosong → tampil fallback.
  final String? photoPath;

  /// Sumber inisial bila foto belum ada.
  final String? name;

  final double radius;

  bool get _hasPhoto {
    final path = photoPath;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    if (_hasPhoto) {
      return CircleAvatar(
        key: const ValueKey<String>('profile-avatar'),
        radius: radius,
        backgroundColor: p.neutral100,
        backgroundImage: FileImage(File(photoPath!)),
      );
    }

    final trimmed = (name ?? '').trim();
    final initial = trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();

    return CircleAvatar(
      key: const ValueKey<String>('profile-avatar'),
      radius: radius,
      backgroundColor: p.primary50,
      child: initial.isEmpty
          ? Icon(Icons.person, size: radius, color: p.primary500)
          : Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
                color: p.primary500,
              ),
            ),
    );
  }
}

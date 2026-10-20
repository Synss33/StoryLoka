import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// Zona 1: Top Bar 56dp, sticky, maksimum 2 ikon aksi (dokumen desain
/// Bagian 2 & Bagian 8). Gaya berasal dari `ThemeData.appBarTheme`.
class StorylokaTopBar extends StatelessWidget implements PreferredSizeWidget {
  const StorylokaTopBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.showBack = false,
    this.leading,
  });

  final String title;

  /// Maksimal 2 aksi; sisanya dibuang (Bagian 2, Zona 1).
  final List<Widget> actions;

  /// Menampilkan tombol `←` untuk layar fokus (Bagian 3.3).
  final bool showBack;

  /// Konten awal tambahan (mis. avatar profil di Beranda — SCR-02);
  /// mengabaikan `automaticallyImplyLeading`.
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(AppLayout.topBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBack,
      leading: leading,
      actions: actions.length > 2 ? actions.sublist(0, 2) : actions,
    );
  }
}

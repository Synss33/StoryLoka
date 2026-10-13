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
  });

  final String title;

  /// Maksimal 2 aksi; sisanya dibuang (Bagian 2, Zona 1).
  final List<Widget> actions;

  /// Menampilkan tombol `←` untuk layar fokus (Bagian 3.3).
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(AppLayout.topBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBack,
      actions: actions.length > 2 ? actions.sublist(0, 2) : actions,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/bottom_nav_bar.dart';
import '../features/auth/auth_controller.dart';

/// Zona 4 Master Layout: wadah 4 tab (Beranda, Explore, Profil, Kesan)
/// + slot Logout. Bottom nav tampil untuk rute di dalam shell
/// (SCR-02, 03, 04, 09, 10, 14 — dokumen desain Bagian 3.3); layar fokus
/// dideklarasikan di luar shell sehingga nav otomatis disembunyikan.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Isi tab dipasang go_router pada Navigator bercabang.
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (index) => navigationShell.goBranch(
          index,
          // Ketuk tab yang sama → kembali ke halaman awal tab tersebut.
          initialLocation: index == navigationShell.currentIndex,
        ),
        onLogout: () => showLogoutConfirmationDialog(context),
      ),
    );
  }
}

/// Dialog konfirmasi Logout (dokumen desain: Dialog Logout / F-09).
///
/// Aksi **Keluar** (WF-02): kembali ke SCR-01, hapus token sesi, tutup
/// database terenkripsi (saat splash menemukan sesi kosong), dan bersihkan
/// state memori. Data buku lokal tetap tersimpan (terenkripsi).
Future<void> showLogoutConfirmationDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final p = AppColors.of(dialogContext);
      return AlertDialog(
        title: const Text('Keluar dari Storyloka?'),
        content: const Text('Sesi akan diakhiri.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            // Aksi berbahaya memakai warna danger-500 (Bagian 1.1).
            style: TextButton.styleFrom(foregroundColor: p.danger500),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // Ambil container lebih dulu — context layar utama segera
              // dibuang setelah berpindah rute.
              final container =
                  ProviderScope.containerOf(context, listen: false);
              context.go('/splash');
              await container
                  .read(authControllerProvider.notifier)
                  .logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      );
    },
  );
}

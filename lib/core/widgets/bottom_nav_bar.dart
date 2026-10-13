import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Bottom navigation 5 slot — dokumen desain Bagian 3.1 dan 8.
///
/// Slot: **Beranda · Explore · Profil · Kesan · Logout**.
/// Indikator aktif: ikon + label `primary-500` dan pil `primary-50`
/// (hanya untuk 4 tab; slot Logout bukan layar, selalu tampil
/// `danger-500` dan hanya membuka dialog konfirmasi).
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onLogout,
  });

  /// Index tab aktif (0 Beranda, 1 Explore, 2 Profil, 3 Kesan).
  final int currentIndex;

  /// Dipanggil ketuk tab 0–3.
  final ValueChanged<int> onSelect;

  /// Slot ke-5 (Logout): hanya membuka dialog konfirmasi,
  /// bukan pindah layar (Bagian 3.1).
  final VoidCallback onLogout;

  static const int _logoutIndex = 4;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    const labels = ['Beranda', 'Explore', 'Profil', 'Kesan', 'Logout'];
    const icons = [
      Icons.home_outlined,
      Icons.explore_outlined,
      Icons.person_outline,
      Icons.forum_outlined,
      Icons.logout,
    ];

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.neutral200)),
      ),
      // Zona 4: tinggi 64dp + safe area bawah.
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppLayout.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: icons[i],
                    label: labels[i],
                    active: i == _logoutIndex ? false : i == currentIndex,
                    logout: i == _logoutIndex,
                    onTap: i == _logoutIndex
                        ? onLogout
                        : () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.logout,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool logout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final color = logout
        ? p.danger500
        : active
            ? p.primary500
            : p.neutral500;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        // Target sentuh minimum 48×48dp.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.touchTarget,
            minHeight: AppSpacing.touchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pil indikator aktif memakai primary-50.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cardGap,
                  vertical: AppSpacing.micro,
                ),
                decoration: BoxDecoration(
                  color: active ? p.primary50 : Colors.transparent,
                  borderRadius: AppRadius.pillAll,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: AppSpacing.micro / 2),
              // Label selalu tampil (Bagian 3.1).
              Text(
                label,
                style: AppTypography.caption.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

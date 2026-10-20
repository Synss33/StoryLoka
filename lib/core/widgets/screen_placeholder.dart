import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import 'empty_state.dart';

/// Badan isi standar untuk layar placeholder WF-01:
/// judul + [EmptyState] (SCR-12) dengan padanan tepi Master Layout —
/// padding 16dp dan ruang bawah 88dp agar tidak tertutup bottom nav.
///
/// Layar SCR-02/04/09/10 memakai ini langsung; layar lain (SCR-01, 03,
/// 05–08, 14–17) hanya dipasangi route agar router siap, isinya
/// diisi pada modul WF-02 s.d. WF-09.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_outlined,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Widget tambahan di bawah EmptyState (mis. status API/DB pada SCR-02).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin,
        AppSpacing.screenMargin,
        AppSpacing.screenMargin,
        88, // ruang bawah Master Layout Zona 2
      ),
      child: Column(
        children: [
          EmptyState(
            title: title,
            description: description,
            icon: icon,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.cardGap),
            footer!,
          ],
        ],
      ),
    );
  }
}

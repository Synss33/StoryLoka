import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// PrimaryButton & SecondaryButton — dokumen desain Bagian 8.
///
/// Tinggi 48dp, radius 12; Secondary = outline `primary-600`.
/// State loading memakai spinner dan menonaktifkan tombol
/// (Bagian 1.4); gaya dasar berasal dari `ThemeData`
/// (`filledButtonTheme` / `outlinedButtonTheme`).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;

  /// `null` atau [loading] `true` → tombol nonaktif.
  final VoidCallback? onPressed;

  /// Menampilkan spinner menggantikan label (Bagian 1.4).
  final bool loading;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _LabelWithIcon(icon: icon, label: label),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      child: loading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _LabelWithIcon(icon: icon, label: label),
    );
  }
}

class _LabelWithIcon extends StatelessWidget {
  const _LabelWithIcon({required this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.grid),
        Text(label),
      ],
    );
  }
}

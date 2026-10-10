import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// SCR-01 — Splash, Register, Login & Biometrik.
///
/// WF-01: splash 1,5 detik (logo + tagline) lalu diteruskan ke Beranda.
/// Form login/register, validasi, sesi, dan biometrik → modul WF-02.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Splash 1,5 detik (dokumen desain Bagian 6, SCR-01).
    // Pengecekan sesi/biometrik ditambahkan di WF-02.
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: p.primary500,
                borderRadius: AppRadius.largeAll,
              ),
              child: Icon(Icons.menu_book, color: p.onPrimary, size: 44),
            ),
            const SizedBox(height: AppSpacing.screenMargin),
            Text(
              'Storyloka',
              style: AppTypography.h1.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              'Temukan, Simpan, & Lacak Bacaanmu',
              style: AppTypography.body2.copyWith(color: p.neutral500),
            ),
            const SizedBox(height: AppSpacing.screenMargin),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.primary500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

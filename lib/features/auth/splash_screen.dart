import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database_provider.dart';
import '../../core/network/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import 'auth_controller.dart';
import 'session_service.dart';

/// SCR-01 — Splash (F-01–F-03).
///
/// Tampil 1,5 detik (logo + tagline) sambil memeriksa sesi, lalu rute
/// sesuai alur sistem workflow Bagian 3.1:
/// * tidak ada sesi        → `/auth` (form login/register)
/// * sesi kedaluwarsa      → `/auth` + dialog "Sesi berakhir" (TC-05)
/// * sesi valid + biometrik→ verifikasi (maks. 3× gagal → form password, TC-07)
/// * sesi valid            → `/` (Beranda, auto-login TC-06)
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    // Splash 1,5 detik (dokumen desain Bagian 6, SCR-01).
    _timer = Timer(const Duration(milliseconds: 1500), _resolve);
  }

  Future<void> _resolve() async {
    if (_resolving || !mounted) return;
    _resolving = true;

    final sessions = ref.read(sessionServiceProvider);
    final auth = ref.read(authControllerProvider.notifier);

    // Urutan sesuai alur workflow Bagian 3.1: cek sesi dulu (tanpa DB),
    // database hanya dibuka bila sesi valid (biometrik & pengaturan).
    final raw = await sessions.rawSession();
    if (raw == null) {
      // Pasca-logout: pastikan koneksi DB ditutup sebelum ke login.
      ref.invalidate(databaseProvider);
      _go('/auth');
      return;
    }

    if (raw.isExpired()) {
      // Sesi kedaluwarsa → hapus lalu ke login dengan pemberitahuan (TC-05).
      await sessions.end();
      ref.invalidate(databaseProvider);
      _go('/auth', extra: 'expired');
      return;
    }

    // Database dibutuhkan untuk pengaturan biometrik dan data pengguna.
    // Segala kegagalan di sini tidak boleh menggantung splash — sesi valid
    // tetap diteruskan ke Beranda.
    try {
      await ref.read(databaseProvider.future);
      auth.adoptSession(raw.userId);
      if (await auth.shouldUseBiometric(raw.userId)) {
        // Verifikasi biometrik: gagal 3× berturut-turut → form password (TC-07).
        for (var attempt = 0; attempt < 3; attempt++) {
          if (await auth.promptBiometric()) {
            auth.resetBiometricFailures();
            _go('/');
            return;
          }
          auth.noteBiometricFailure();
        }
        _go('/auth', extra: 'biometric');
        return;
      }
      _go('/');
    } catch (e) {
      debugPrint('[splash] gagal memeriksa biometrik: $e');
      _go('/');
    }
  }

  void _go(String location, {Object? extra}) {
    if (!mounted) return;
    context.go(location, extra: extra);
    // Masuk Beranda dengan sesi valid → proses antrean sinkronisasi (WF-03).
    // Bila offline, SyncService menjadwalkan coba ulang dengan backoff.
    if (location == '/') _kickSync();
  }

  /// Memulai sinkronisasi tanpa menunggu (kegagalan tidak mengganggu UI).
  void _kickSync() {
    ref
        .read(syncServiceProvider.future)
        .then((service) => service?.kick())
        .catchError((Object e) => debugPrint('[sync] gagal memulai: $e'));
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

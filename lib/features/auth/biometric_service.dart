import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Pembungkus `local_auth` untuk verifikasi biometrik (F-03).
///
/// Semua metode gagal dengan aman (`false`) bila perangkat tidak mendukung,
/// sehingga UI cukup menyembunyikan tombol biometrik (SCR-01).
class BiometricService {
  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Perangkat mendukung biometrik **atau** kredensial layar (PIN/pola).
  Future<bool> isSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Meminta verifikasi. [persistAcrossBackgrounding] mempertahankan prompt
  /// saat aplikasi sesaat berpindah latar belakang.
  Future<bool> authenticate({
    String reason = 'Verifikasi identitas untuk masuk ke Storyloka',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => BiometricService(),
);

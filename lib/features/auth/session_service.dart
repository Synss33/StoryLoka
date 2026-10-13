import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/session.dart';
import 'auth_store.dart';

/// Layanan sesi: membuat, memeriksa, dan mengakhiri sesi login
/// (alur sistem workflow Bagian 3.1–3.2).
class SessionService {
  SessionService(this._store);

  final AuthStore _store;

  /// Sesi aktif yang masih berlaku; null bila tidak ada / sudah kedaluwarsa.
  /// Sesi kedaluwarsa langsung dihapus agar tidak dipakai lagi (TC-05).
  Future<SessionInfo?> validSession({DateTime? now}) async {
    final session = await _store.readSession();
    if (session == null) return null;
    if (session.isExpired(now: now)) {
      await _store.clearSession();
      return null;
    }
    return session;
  }

  /// Membaca sesi apa adanya (untuk membedakan "tidak ada" vs "kedaluwarsa").
  Future<SessionInfo?> rawSession() => _store.readSession();

  /// Membuat sesi baru setelah login/registrasi berhasil.
  Future<SessionInfo> start(int userId) async {
    final session = SessionRules.create(userId);
    await _store.writeSession(session);
    return session;
  }

  /// Menghapus sesi (logout).
  Future<void> end() => _store.clearSession();
}

/// Penyimpanan sesi aplikasi.
final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(authStoreProvider)),
);

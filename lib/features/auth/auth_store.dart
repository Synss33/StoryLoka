import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/security/session.dart';

/// Penyimpanan sesi & penanda pengguna aktif.
///
/// Dibuat sebagai abstraksi agar unit test dapat mengganti implementasinya
/// dengan penyimpanan memori (tanpa plugin secure storage di host).
abstract class AuthStore {
  /// Mengembalikan sesi tersimpan, atau null bila belum ada / rusak.
  Future<SessionInfo?> readSession();

  /// Menyimpan sesi (token, user, masa berlaku) ke secure storage.
  Future<void> writeSession(SessionInfo session);

  /// Menghapus sesi (dipakai logout & sesi kedaluwarsa).
  Future<void> clearSession();
}

/// Implementasi produksi: Keychain (iOS) / Keystore (Android).
///
/// Token sesi WAJIB di secure storage — dilarang memakai SharedPreferences
/// biasa (workflow Bagian 4.3).
class SecureAuthStore implements AuthStore {
  SecureAuthStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  // Alias key (bukan nilai rahasia, hanya penanda).
  static const String sessionKey = 'storyloka.session';

  @override
  Future<SessionInfo?> readSession() async {
    final raw = await _storage.read(key: sessionKey);
    return SessionInfo.tryParse(raw);
  }

  @override
  Future<void> writeSession(SessionInfo session) =>
      _storage.write(key: sessionKey, value: session.toJson());

  @override
  Future<void> clearSession() => _storage.delete(key: sessionKey);
}

/// Implementasi untuk unit test (tanpa plugin native).
class InMemoryAuthStore implements AuthStore {
  SessionInfo? session;

  @override
  Future<SessionInfo?> readSession() async => session;

  @override
  Future<void> writeSession(SessionInfo s) async => session = s;

  @override
  Future<void> clearSession() async => session = null;
}

/// Penyimpanan sesi aktif aplikasi.
final authStoreProvider = Provider<AuthStore>((ref) => SecureAuthStore());

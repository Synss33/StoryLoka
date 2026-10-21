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

  /// Token sesi **server** (balasan `POST /auth/register|login`) untuk
  /// endpoint butuh-otorisasi (`/ai`, `/rates`, `/feedback`, `/sync`);
  /// null bila belum pernah login server / sudah kedaluwarsa.
  Future<String?> readServerToken();

  /// Menyimpan token sesi server (bila balasan login/register berisi token).
  Future<void> writeServerToken(String token);

  /// Menghapus token sesi server (logout).
  Future<void> clearServerToken();
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
  static const String serverTokenKey = 'storyloka.serverToken';

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

  @override
  Future<String?> readServerToken() => _storage.read(key: serverTokenKey);

  @override
  Future<void> writeServerToken(String token) =>
      _storage.write(key: serverTokenKey, value: token);

  @override
  Future<void> clearServerToken() => _storage.delete(key: serverTokenKey);
}

/// Implementasi untuk unit test (tanpa plugin native).
class InMemoryAuthStore implements AuthStore {
  SessionInfo? session;
  String? serverToken;

  @override
  Future<SessionInfo?> readSession() async => session;

  @override
  Future<void> writeSession(SessionInfo s) async => session = s;

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String?> readServerToken() async => serverToken;

  @override
  Future<void> writeServerToken(String token) async => serverToken = token;

  @override
  Future<void> clearServerToken() async => serverToken = null;
}

/// Penyimpanan sesi aplikasi.
final authStoreProvider = Provider<AuthStore>((ref) => SecureAuthStore());

/// Token untuk panggilan API butuh-otorisasi (`requireAuth` di backend).
///
/// Utama: token sesi **server** (balasan register/login). Cadangan: token
/// sesi lokal — agar offline / test host tetap berperilaku seperti sekarang
/// (server tetap menolaknya, tetapi tidak merusak alur offline-first).
Future<String?> onlineToken(Ref ref) async {
  final store = ref.read(authStoreProvider);
  final server = await store.readServerToken();
  if (server != null && server.isNotEmpty) return server;
  final session = await store.readSession();
  return session?.token;
}

/// Varian [onlineToken] untuk ConsumerWidget/ConsumerState (Ref-nya lewat).
Future<String?> onlineTokenOf(AuthStore store) async {
  final server = await store.readServerToken();
  if (server != null && server.isNotEmpty) return server;
  final session = await store.readSession();
  return session?.token;
}

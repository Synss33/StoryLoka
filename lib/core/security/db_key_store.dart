import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan kunci enkripsi database lokal.
///
/// Kunci dibuat **acak 256-bit** saat pertama kali database dibuka dan
/// disimpan di Keychain/Keystore lewat `flutter_secure_storage`.
/// Kunci sengaja **tidak diturunkan dari password** pengguna agar
/// login biometrik tetap dapat membuka database (deskripsi Bagian 5.1).
abstract final class DbKeyStore {
  /// Alias kunci di secure storage (bukan nilai rahasia, hanya penanda).
  static const String dbKeyAlias = 'storyloka.db.key';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Mengambil kunci; membuat baru bila belum ada.
  static Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: dbKeyAlias);
    if (existing != null && existing.length == 64) return existing;

    final key = generateDbKey();
    await _storage.write(key: dbKeyAlias, value: key);
    return key;
  }

  /// Menghapus kunci (dipakai saat logout/beri tahu WF-02).
  static Future<void> deleteKey() => _storage.delete(key: dbKeyAlias);

  /// Kunci acak 256-bit = 32 byte → 64 karakter heksadesimal.
  /// Memakai [Random.secure] (CSPRNG OS), bukan `Random` biasa.
  static String generateDbKey() {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

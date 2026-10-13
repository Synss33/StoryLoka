import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Hash password dengan **PBKDF2-HMAC-SHA256 + salt unik per pengguna**
/// (deskripsi proyek Bagian 5.1 mengizinkan Argon2id **atau** PBKDF2;
/// PBKDF2 dipilih karena implementasi Dart murni → bisa diuji di host
/// tanpa plugin native — lihat `docs/keputusan.md`).
///
/// Yang disimpan di tabel `users` hanya **hash, salt, dan parameter KDF**;
/// password polos tidak pernah ditulis ke mana pun.
abstract final class PasswordHasher {
  /// Panjang salt dalam byte (dibuat acak untuk tiap pengguna).
  static const int saltBytes = 16;

  /// Panjang output hash dalam byte (256 bit).
  static const int hashBytes = 32;

  /// Jumlah iterasi PBKDF2 (rekomendasi OWASP untuk PBKDF2-HMAC-SHA256).
  ///
  /// Berupa statis non-konstan agar unit test dapat menurunkannya sementara
  /// (hash 210 ribu iterasi terlalu lambat untuk test); nilai produksi
  /// dikunci lewat [defaultIterations].
  static const int defaultIterations = 210000;
  static int iterations = defaultIterations;

  /// Nama algoritma yang dicatat ke kolom `users.kdf_params`.
  static const String algorithm = 'PBKDF2-HMAC-SHA256';

  /// Salt acak baru (hex 32 karakter) untuk pengguna baru.
  static String newSaltHex() {
    final rng = Random.secure();
    final bytes = List<int>.generate(saltBytes, (_) => rng.nextInt(256));
    return _toHex(bytes);
  }

  /// Menghitung hash dari [password] + [saltHex].
  static Future<String> hash(String password, String saltHex) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: hashBytes * 8,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: _fromHex(saltHex),
    );
    return _toHex(await key.extractBytes());
  }

  /// Verifikasi [password] terhadap hash tersimpan (perbandingan constant-time).
  static Future<bool> verify({
    required String password,
    required String saltHex,
    required String expectedHashHex,
  }) async {
    final actual = await hash(password, saltHex);
    return constantTimeEquals(actual, expectedHashHex);
  }

  /// Nilai kolom `users.kdf_params` (JSON) — mencatat algoritma + parameter
  /// agar generasi hash berikutnya dapat direproduksi.
  static String kdfParamsJson() => jsonEncode(<String, Object>{
        'algo': algorithm,
        'iterations': iterations,
        'hashLength': hashBytes,
        'saltEncoding': 'hex',
      });

  /// Perbandingan dua string heksadesimal tanpa short-circuit
  /// (mencegah timing attack sederhana).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  static Uint8List _fromHex(String hex) => Uint8List.fromList(
        List<int>.generate(hex.length ~/ 2,
            (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)),
      );
}

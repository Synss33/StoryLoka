import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/security/password_hasher.dart';

/// Uji hash password PBKDF2-HMAC-SHA256 + salt (F-01, TC-04).
void main() {
  setUp(() {
    // Iterasi diturunkan agar test cepat; parameter produksi dicek terpisah.
    PasswordHasher.iterations = 1000;
  });

  tearDown(() {
    PasswordHasher.iterations = PasswordHasher.defaultIterations;
  });

  test('parameter KDF produksi memakai PBKDF2-HMAC-SHA256 210.000 iterasi',
      () {
    expect(PasswordHasher.defaultIterations, 210000);
    expect(PasswordHasher.algorithm, 'PBKDF2-HMAC-SHA256');
    expect(PasswordHasher.saltBytes, 16);
    expect(PasswordHasher.hashBytes, 32);
  });

  test('salt baru berbeda tiap pembuatan dan berformat hex', () {
    final a = PasswordHasher.newSaltHex();
    final b = PasswordHasher.newSaltHex();
    expect(a.length, 32);
    expect(b.length, 32);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(a), isTrue);
    expect(a, isNot(equals(b)));
  });

  test('hash → verify benar; password salah → verify gagal', () async {
    const password = 'KataSandi!123';
    final salt = PasswordHasher.newSaltHex();
    final hash = await PasswordHasher.hash(password, salt);

    expect(hash.length, 64);
    // Tidak ada teks polos di hash (TC-04).
    expect(hash.contains(password), isFalse);

    expect(
      await PasswordHasher.verify(
        password: password,
        saltHex: salt,
        expectedHashHex: hash,
      ),
      isTrue,
    );
    expect(
      await PasswordHasher.verify(
        password: 'password-salah',
        saltHex: salt,
        expectedHashHex: hash,
      ),
      isFalse,
    );
  });

  test('salt berbeda menghasilkan hash berbeda untuk password sama', () async {
    const password = 'KataSandi!123';
    final h1 = await PasswordHasher.hash(password, PasswordHasher.newSaltHex());
    final h2 = await PasswordHasher.hash(password, PasswordHasher.newSaltHex());
    expect(h1, isNot(equals(h2)));
  });

  test('kdf_params JSON dapat diparse dan memuat algoritma + iterasi', () {
    final params = PasswordHasher.kdfParamsJson();
    expect(params, contains('PBKDF2-HMAC-SHA256'));
    expect(params, contains('"iterations":1000'));
  });
}

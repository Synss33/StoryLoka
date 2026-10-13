import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/db/database_provider.dart';
import '../../core/security/password_hasher.dart';

/// Galat autentikasi dengan pesan siap tampil (Bahasa Indonesia).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Data baris `users` yang dibaca dari database.
class UserRecord {
  const UserRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.photoPath,
  });

  final int id;
  final String name;
  final String email;
  final String passwordHash;
  final String salt;
  final String? photoPath;
}

/// Akses tabel `users` untuk autentikasi lokal (deskripsi Bagian 5.1).
class UserRepository {
  UserRepository(this._db);

  final Database _db;

  /// Registrasi pengguna baru: salt + hash disimpan, password polos
  /// tidak pernah ditulis (TC-04).
  Future<UserRecord> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final salt = PasswordHasher.newSaltHex();
    final hash = await PasswordHasher.hash(password, salt);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final id = await _db.insert('users', <String, Object?>{
        'name': name.trim(),
        'email': _normalizeEmail(email),
        'password_hash': hash,
        'salt': salt,
        'kdf_params': PasswordHasher.kdfParamsJson(),
        'created_at': now,
        'updated_at': now,
      });
      return UserRecord(
        id: id,
        name: name.trim(),
        email: _normalizeEmail(email),
        passwordHash: hash,
        salt: salt,
        photoPath: null,
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AuthException('Email sudah terdaftar. Silakan masuk.');
      }
      rethrow;
    }
  }

  /// Cari pengguna berdasarkan email **atau** nama (label field SCR-01:
  /// "Email / Username").
  Future<UserRecord?> findByEmailOrName(String input) async {
    final value = input.trim();
    if (value.isEmpty) return null;
    final rows = await _db.query(
      'users',
      where: 'LOWER(email) = ? OR LOWER(name) = ?',
      whereArgs: [value.toLowerCase(), value.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<UserRecord?> byId(int id) async {
    final rows =
        await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  /// Verifikasi password terhadap hash tersimpan (constant-time).
  Future<bool> verifyPassword(UserRecord user, String password) {
    return PasswordHasher.verify(
      password: password,
      saltHex: user.salt,
      expectedHashHex: user.passwordHash,
    );
  }

  /// Memperbarui profil (nama, email, foto) — SCR-17 (WF-04).
  /// [photoPath] `null` = foto tidak diubah.
  Future<void> updateProfile({
    required int id,
    required String name,
    required String email,
    String? photoPath,
  }) async {
    if (name.trim().isEmpty) {
      throw const AuthException('Nama lengkap wajib diisi.');
    }
    if (!_isEmail(email)) {
      throw const AuthException('Format email tidak valid.');
    }
    final updates = <String, Object>{
      'name': name.trim(),
      'email': _normalizeEmail(email),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (photoPath != null) updates['photo_path'] = photoPath;
    try {
      final count = await _db.update(
        'users',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw const AuthException('Pengguna tidak ditemukan.');
      }
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw const AuthException('Email sudah dipakai akun lain.');
      }
      rethrow;
    }
  }

  /// Ganti password dengan verifikasi password lama — SCR-17 (WF-04).
  Future<void> updatePassword({
    required int id,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = await byId(id);
    if (user == null) {
      throw const AuthException('Pengguna tidak ditemukan.');
    }
    if (!await verifyPassword(user, currentPassword)) {
      throw const AuthException('Password lama salah.');
    }
    if (newPassword.length < 8) {
      throw const AuthException('Password baru minimal 8 karakter.');
    }
    final salt = PasswordHasher.newSaltHex();
    final hash = await PasswordHasher.hash(newPassword, salt);
    await _db.update(
      'users',
      <String, Object>{
        'password_hash': hash,
        'salt': salt,
        'kdf_params': PasswordHasher.kdfParamsJson(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static bool _isEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static UserRecord _fromRow(Map<String, Object?> row) => UserRecord(
        id: row['id'] as int,
        name: row['name'] as String,
        email: row['email'] as String,
        passwordHash: row['password_hash'] as String,
        salt: row['salt'] as String,
        photoPath: row['photo_path'] as String?,
      );
}

/// Membuat repository dari database yang sudah terbuka.
final userRepositoryProvider = FutureProvider<UserRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) {
    throw const AuthException('Database tidak tersedia di perangkat ini.');
  }
  return UserRepository(db);
});

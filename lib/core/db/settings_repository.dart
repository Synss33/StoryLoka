import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_provider.dart';

/// Akses tabel `settings` (wf-02 hanya memakai `biometric_enabled`;
/// tema, pengingat, dan target bulanan menyusul di WF-04/WF-06).
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  /// Membuat baris pengaturan default bila belum ada (INSERT OR IGNORE).
  Future<void> ensureRow(int userId) async {
    await _db.insert(
      'settings',
      <String, Object?>{'user_id': userId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> isBiometricEnabled(int userId) async {
    await ensureRow(userId);
    final rows = await _db.query(
      'settings',
      columns: ['biometric_enabled'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['biometric_enabled'] == 1;
  }

  Future<void> setBiometricEnabled(int userId, bool enabled) async {
    await ensureRow(userId);
    await _db.update(
      'settings',
      <String, Object>{'biometric_enabled': enabled ? 1 : 0},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}

/// Repository pengaturan dari database aktif (null bila DB tidak terbuka).
final settingsRepositoryProvider =
    FutureProvider<SettingsRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return SettingsRepository(db);
});

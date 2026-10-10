import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/app_settings.dart';
import 'database_provider.dart';

/// Akses tabel `settings` (WF-02: `biometric_enabled`; WF-03: `last_sync`
/// + `updated_at` untuk sinkronisasi; tema/pengingat/target menyusul
/// WF-04/WF-06).
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
      <String, Object>{
        'biometric_enabled': enabled ? 1 : 0,
        // Perubahan pengaturan wajib memperbarui waktu agar LWW bekerja.
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Membaca seluruh baris pengaturan (untuk payload sinkronisasi).
  Future<AppSettings?> read(int userId) async {
    await ensureRow(userId);
    final rows = await _db.query(
      'settings',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppSettings.fromRow(rows.first);
  }

  /// Menyimpan pilihan tema (`auto`/`light`/`dark`) — SCR-09 (WF-04).
  Future<void> setThemeMode(int userId, String mode) async {
    await ensureRow(userId);
    await _db.update(
      'settings',
      <String, Object>{
        'theme_mode': mode,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Menyimpan pengaturan pengingat harian (ON/OFF + jam) — SCR-09.
  /// Penjadwalan notifikasinya sendiri dikerjakan WF-06.
  Future<void> setReminder(int userId, {required bool on, String? time}) async {
    await ensureRow(userId);
    await _db.update(
      'settings',
      <String, Object>{
        'reminder_on': on ? 1 : 0,
        if (time != null) 'reminder_time': time,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Menyimpan toggle notifikasi target & streak (skema v3) — SCR-09.
  Future<void> setStreakNotify(int userId, bool enabled) async {
    await ensureRow(userId);
    await _db.update(
      'settings',
      <String, Object>{
        'streak_notify': enabled ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Menerapkan pengaturan dari server (dipanggil SyncService setelah LWW
  /// memutus server menang).
  Future<void> applyServer(AppSettings settings) async {
    await _db.insert(
      'settings',
      settings.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mencatat waktu sinkronisasi terakhir (kolom `last_sync`).
  Future<void> setLastSync(int userId, int epochMs) async {
    await ensureRow(userId);
    await _db.update(
      'settings',
      <String, Object>{'last_sync': epochMs},
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

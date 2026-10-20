import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/app_notification.dart';
import 'database_provider.dart';

/// Akses tabel `notifications` — riwayat pengingat/target/streak/
/// sertifikat (SCR-14, F-14 / WF-06). Tabel sudah ada sejak skema v1.
class NotificationRepository {
  NotificationRepository(this._db);

  final Database _db;

  Future<int> insert(AppNotification notification) =>
      _db.insert('notifications', notification.toRow());

  /// Riwayat terbaru milik [userId] (default 50 baris teratas).
  Future<List<AppNotification>> list(int userId, {int limit = 50}) async {
    final rows = await _db.query(
      'notifications',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(AppNotification.fromRow).toList(growable: false);
  }

  Future<int> unreadCount(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications '
      'WHERE user_id = ? AND read = 0',
      <Object?>[userId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markRead(int id) => _db.update(
        'notifications',
        <String, Object>{'read': 1},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

  Future<void> markAllRead(int userId) => _db.update(
        'notifications',
        <String, Object>{'read': 1},
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      );

  /// Menandai seluruh riwayat bertipe [type] sebagai dibaca (dipakai saat
  /// notifikasi sistem bertipe tersebut diketuk).
  Future<void> markTypeRead(int userId, String type) => _db.update(
        'notifications',
        <String, Object>{'read': 1},
        where: 'user_id = ? AND type = ? AND read = 0',
        whereArgs: <Object?>[userId, type],
      );

  /// Sudah ada riwayat bertipe [type] hari ini? (dedupe event & pengingat)
  Future<bool> existsToday(int userId, String type) async {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final rows = await _db.query(
      'notifications',
      columns: ['id'],
      where: 'user_id = ? AND type = ? AND created_at >= ?',
      whereArgs: <Object?>[userId, type, startOfDay],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}

/// Repository dari database aktif (null bila DB belum terbuka).
final notificationRepositoryProvider =
    FutureProvider<NotificationRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return NotificationRepository(db);
});

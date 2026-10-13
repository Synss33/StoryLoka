import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/feedback_item.dart';
import 'database_provider.dart';

/// Akses tabel `feedback` (kesan & saran — SCR-10 dikerjakan WF-04).
///
/// Penanda `synced = 0` menjadikan baris sebagai antrean kirim; setelah
/// diterima server, `SyncService` menyetelnya menjadi 1.
class FeedbackRepository {
  FeedbackRepository(this._db);

  final Database _db;

  static const List<String> _columns = [
    'id',
    'user_id',
    'kesan',
    'saran',
    'updated_at',
    'synced',
  ];

  /// Menyimpan kesan/saran pengguna (upsert per pengguna + tandai belum
  /// tersinkron). Satu baris per pengguna agar isian terakhir menimpa
  /// yang lama (SCR-10).
  Future<void> save(FeedbackItem feedback) async {
    final existing = await _db.query(
      'feedback',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [feedback.userId],
      limit: 1,
    );
    final row = feedback.toRow();
    if (existing.isNotEmpty) row['id'] = existing.first['id'];
    row['synced'] = 0;
    row['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      'feedback',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FeedbackItem?> read(int userId) async {
    final rows = await _db.query(
      'feedback',
      columns: _columns,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FeedbackItem.fromRow(rows.first);
  }

  /// Antrean kirim: baris dengan `synced = 0`.
  Future<List<FeedbackItem>> pendingSync() async {
    final rows = await _db.query(
      'feedback',
      columns: _columns,
      where: 'synced = 0',
      orderBy: 'updated_at ASC',
    );
    return rows.map(FeedbackItem.fromRow).toList();
  }

  Future<void> markSynced(Iterable<int> ids) async {
    for (final id in ids) {
      await _db.update(
        'feedback',
        <String, Object>{'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Menerapkan dari server (LWW by `updated_at`).
  Future<void> applyServer(FeedbackItem server) async {
    if (server.id == null) return;
    final rows = await _db.query(
      'feedback',
      columns: ['updated_at'],
      where: 'user_id = ?',
      whereArgs: [server.userId],
      limit: 1,
    );
    if (rows.isNotEmpty &&
        (rows.first['updated_at'] as int) >= server.updatedAt) {
      return; // lokal menang
    }
    final row = server.toRow();
    row['synced'] = 1; // data dari server sudah pasti ada di server
    await _db.insert(
      'feedback',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Repository feedback dari database aktif.
final feedbackRepositoryProvider =
    FutureProvider<FeedbackRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return FeedbackRepository(db);
});

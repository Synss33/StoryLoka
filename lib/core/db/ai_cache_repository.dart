import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_provider.dart';

/// Akses tabel `ai_cache` (F-11 — Bagian 5.6): hasil ringkasan AI per buku
/// disimpan agar tetap tampil saat offline ("hasil ringkasan di-cache lokal").
class AiCacheRepository {
  AiCacheRepository(this._db);

  final Database _db;

  /// Menyimpan/menimpa isi cache ber-Kunci [key] (mis. `summary:<bookId>`).
  Future<void> save({
    required int userId,
    required String key,
    required String content,
  }) async {
    await _db.insert(
      'ai_cache',
      <String, Object>{
        'key': key,
        'user_id': userId,
        'content': content,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Membaca isi cache; `null` bila belum pernah tersimpan.
  Future<String?> read(String key) async {
    final rows = await _db.query(
      'ai_cache',
      columns: <String>['content'],
      where: 'key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['content'] as String?;
  }
}

final aiCacheRepositoryProvider =
    FutureProvider<AiCacheRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return AiCacheRepository(db);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/block.dart';
import 'database_provider.dart';

/// Akses tabel `blocks` — hash chain lokal "Proof of Reading" (Bagian 5.7).
///
/// Append-only dengan PK `(user_id, idx)`; server menyimpan salinan sebagai
/// *anchor* pembanding rantai (Bagian 5.7).
class BlockRepository {
  BlockRepository(this._db);

  final Database _db;

  static const List<String> _columns = [
    'idx',
    'user_id',
    'timestamp',
    'book_id',
    'review_hash',
    'finished_date',
    'previous_hash',
    'hash',
  ];

  Future<void> append(Block block) =>
      _db.insert('blocks', block.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<List<Block>> listByUser(int userId) async {
    final rows = await _db.query(
      'blocks',
      columns: _columns,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'idx ASC',
    );
    return rows.map(Block.fromRow).toList();
  }

  Future<int?> maxIdx(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(idx) AS max_idx FROM blocks WHERE user_id = ?',
      [userId],
    );
    return rows.first['max_idx'] as int?;
  }

  /// Blok terakhir (idx terbesar) milik pengguna — dasar `previous_hash`
  /// blok berikutnya saat buku baru selesai (WF-08).
  Future<Block?> lastByUser(int userId) async {
    final rows = await _db.query(
      'blocks',
      columns: _columns,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'idx DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Block.fromRow(rows.first);
  }

  /// Blok milik buku tertentu (sertifikat "Proof of Reading" SCR-06);
  /// null bila buku belum pernah menghasilkan blok.
  Future<Block?> findByBook(int userId, int bookId) async {
    final rows = await _db.query(
      'blocks',
      columns: _columns,
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
      orderBy: 'idx DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Block.fromRow(rows.first);
  }

  /// Snapshot server: tambahkan blok yang belum dimiliki (idempoten).
  Future<void> applySnapshot(List<Block> serverBlocks) async {
    for (final block in serverBlocks) {
      await _db.insert(
        'blocks',
        block.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

/// Repository blok dari database aktif.
final blockRepositoryProvider = FutureProvider<BlockRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return BlockRepository(db);
});

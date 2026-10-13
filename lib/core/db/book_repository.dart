import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database_provider.dart';
import '../models/book.dart';

/// CRUD buku offline pada tabel `books` (F-04, deskripsi Bagian 5.2).
///
/// Aturan penanda sinkronisasi WF-03:
/// * setiap perubahan lokal menyetel `dirty = 1` dan `updated_at = now`;
/// * `SyncService` mengirim baris `dirty = 1` lalu menyetelnya kembali 0;
/// * hapus = *soft delete* (`deleted = 1`, tetap `dirty = 1`).
class BookRepository {
  BookRepository(this._db);

  final Database _db;

  static const List<String> _columns = [
    'id',
    'user_id',
    'title',
    'author',
    'publisher',
    'year',
    'isbn',
    'genre',
    'pages',
    'cover',
    'synopsis',
    'status',
    'rating',
    'price',
    'started_at',
    'finished_at',
    'updated_at',
    'deleted',
    'dirty',
  ];

  int _now() => DateTime.now().millisecondsSinceEpoch;

  /// Daftar buku milik [userId]; default tanpa yang terhapus, terbaru dulu.
  Future<List<Book>> list(
    int userId, {
    String? status,
    bool includeDeleted = false,
    String orderBy = 'updated_at DESC',
  }) async {
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (!includeDeleted) where.add('deleted = 0');
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    final rows = await _db.query(
      'books',
      columns: _columns,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: orderBy,
    );
    return rows.map(Book.fromRow).toList();
  }

  Future<Book?> get(int id) async {
    final rows = await _db.query(
      'books',
      columns: _columns,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromRow(rows.first);
  }

  /// Menyimpan buku baru (insert). Mengembalikan id baris.
  Future<int> insert(Book book) async {
    final row = book.toRow();
    row['updated_at'] = _now();
    row['dirty'] = 1;
    return _db.insert('books', row);
  }

  /// Memperbarui buku yang ada — selalu dianggap perubahan lokal (dirty).
  Future<void> update(Book book) async {
    if (book.id == null) return;
    final row = book.toRow();
    row.remove('id');
    row['updated_at'] = _now();
    row['dirty'] = 1;
    await _db.update(
      'books',
      row,
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// Hapus lunak (data tetap tersimpan terenkripsi — Bagian 5.1 logout).
  Future<void> softDelete(int id) async {
    await _db.update(
      'books',
      <String, Object>{'deleted': 1, 'dirty': 1, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Baris yang belum tersinkron (antrean kirim ke server).
  Future<List<Book>> pendingSync(int userId) async {
    final books = await list(
      userId,
      includeDeleted: true,
      orderBy: 'updated_at ASC',
    );
    return books.where((b) => b.dirty).toList();
  }

  /// Menerapkan buku dari server: bila `updated_at` server lebih baru,
  /// baris lokal diganti; bila lebih lama, lokal menang (LWW) dan hasil
  /// kembalian `true` bila baris lokal perlu disimpan ulang.
  ///
  /// Baris hasil server selalu bersih (`dirty = 0`).
  Future<void> applyServer(Book server) async {
    final local = server.id == null ? null : await get(server.id!);
    if (local != null && local.updatedAt >= server.updatedAt) {
      // LWW: lokal sama/baru lebih — cukup tandai sudah tersinkron.
      if (local.dirty) {
        await _db.update(
          'books',
          <String, Object>{'dirty': 0},
          where: 'id = ?',
          whereArgs: [local.id],
        );
      }
      return;
    }
    final row = server.toRow();
    row['dirty'] = 0;
    await _db.insert(
      'books',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Menyetel `dirty = 0` untuk buku yang sudah diterima server.
  Future<void> markSynced(Iterable<int> ids) async {
    for (final id in ids) {
      await _db.update(
        'books',
        <String, Object>{'dirty': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}

/// Repository buku dari database aktif (null bila DB tidak terbuka).
final bookRepositoryProvider = FutureProvider<BookRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return BookRepository(db);
});

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
  ///
  /// [query] menyaring judul/penulis/ISBN (pencarian lokal SCR-03/SCR-08);
  /// [genre], [minRating], dan [year] menyaring hasil (filter SCR-08,
  /// TC-14); [excludeWishlist] membatasi tab Koleksi (bagian 7: buku
  /// `wishlist` hanya muncul di tab Wishlist); [orderBy] menerima
  /// `updated_at DESC` (terbaru), `title ASC` (judul), atau
  /// `rating DESC` (rating).
  Future<List<Book>> list(
    int userId, {
    String? status,
    bool includeDeleted = false,
    bool excludeWishlist = false,
    String? query,
    String? genre,
    double? minRating,
    int? year,
    String orderBy = 'updated_at DESC',
  }) async {
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (!includeDeleted) where.add('deleted = 0');
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    } else if (excludeWishlist) {
      where.add('status != ?');
      args.add('wishlist');
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where.add('(title LIKE ? OR author LIKE ? OR isbn LIKE ?)');
      args.addAll([q, q, q]);
    }
    if (genre != null && genre.isNotEmpty) {
      where.add('genre = ?');
      args.add(genre);
    }
    if (minRating != null) {
      where.add('rating IS NOT NULL AND rating >= ?');
      args.add(minRating);
    }
    if (year != null) {
      where.add('year = ?');
      args.add(year);
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

  /// Daftar genre unik milik pengguna (untuk opsi filter SCR-08).
  Future<List<String>> genres(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT genre FROM books '
      'WHERE user_id = ? AND deleted = 0 AND genre IS NOT NULL AND genre != \'\' '
      'ORDER BY genre ASC',
      <Object?>[userId],
    );
    return rows
        .map((r) => r['genre'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Daftar tahun terbit unik milik pengguna (untuk opsi filter SCR-08).
  Future<List<int>> years(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT year FROM books '
      'WHERE user_id = ? AND deleted = 0 AND year IS NOT NULL '
      'ORDER BY year DESC',
      <Object?>[userId],
    );
    return rows
        .map((r) => r['year'] as num?)
        .whereType<num>()
        .map((y) => y.toInt())
        .toList();
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

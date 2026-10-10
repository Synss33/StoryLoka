import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/review.dart';
import 'database_provider.dart';

/// Akses tabel `reviews` (F-04). Append-only — ulasan dibuat sekali saat
/// buku selesai (WF-05) dan dipakai blockchain (WF-08).
class ReviewRepository {
  ReviewRepository(this._db);

  final Database _db;

  static const List<String> _columns = ['id', 'book_id', 'rating', 'text', 'created_at'];

  Future<int> insert(Review review) => _db.insert('reviews', review.toRow());

  Future<List<Review>> listByBook(int bookId) async {
    final rows = await _db.query(
      'reviews',
      columns: _columns,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Review.fromRow).toList();
  }

  Future<List<Review>> listAll() async {
    final rows = await _db.query('reviews', columns: _columns, orderBy: 'created_at ASC');
    return rows.map(Review.fromRow).toList();
  }

  /// Snapshot server: tambahkan baris yang belum dimiliki (idempoten).
  Future<void> applySnapshot(List<Review> serverReviews) async {
    for (final review in serverReviews) {
      if (review.id == null) continue;
      await _db.insert(
        'reviews',
        review.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

/// Repository ulasan dari database aktif.
final reviewRepositoryProvider =
    FutureProvider<ReviewRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return ReviewRepository(db);
});

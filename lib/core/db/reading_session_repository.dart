import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/reading_session.dart';
import 'database_provider.dart';

/// Akses tabel `reading_sessions` (F-04; dipakai WF-05 & sinkron WF-03).
///
/// Baris bersifat *append-only*; `updated_at` dipakai untuk *last-write-wins*.
class ReadingSessionRepository {
  ReadingSessionRepository(this._db);

  final Database _db;

  static const List<String> _columns = [
    'id',
    'book_id',
    'start_ts',
    'duration_sec',
    'last_page',
    'note',
    'updated_at',
  ];

  /// Mencatat sesi baru (durasi sudah dihitung dari timestamp di pemanggil).
  Future<int> insert(ReadingSession session) =>
      _db.insert('reading_sessions', session.toRow());

  Future<List<ReadingSession>> listByBook(int bookId) async {
    final rows = await _db.query(
      'reading_sessions',
      columns: _columns,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'start_ts DESC',
    );
    return rows.map(ReadingSession.fromRow).toList();
  }

  Future<List<ReadingSession>> listAll() async {
    final rows = await _db.query(
      'reading_sessions',
      columns: _columns,
      orderBy: 'start_ts ASC',
    );
    return rows.map(ReadingSession.fromRow).toList();
  }

  /// Halaman terakhir terjauh pada sebuah buku — dasar progres % di
  /// SCR-02/SCR-06 (buku tidak menyimpan kolom halaman terkini).
  Future<int> furthestPage(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(last_page) AS p FROM reading_sessions WHERE book_id = ?',
      <Object?>[bookId],
    );
    final value = rows.isEmpty ? null : rows.first['p'];
    return value is num ? value.toInt() : 0;
  }

  /// Total durasi (detik) seluruh sesi sebuah buku — "total jam" SCR-06.
  Future<int> totalDurationSec(int bookId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(duration_sec), 0) AS d '
      'FROM reading_sessions WHERE book_id = ?',
      <Object?>[bookId],
    );
    final value = rows.isEmpty ? null : rows.first['d'];
    return value is num ? value.toInt() : 0;
  }

  /// Menerapkan sesi dari server: LWW by `updated_at`; insert bila belum ada.
  Future<void> applyServer(ReadingSession server) async {
    if (server.id == null) return;
    final rows = await _db.query(
      'reading_sessions',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [server.id],
      limit: 1,
    );
    if (rows.isNotEmpty &&
        (rows.first['updated_at'] as int) >= server.updatedAt) {
      return; // lokal menang
    }
    await _db.insert(
      'reading_sessions',
      server.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Repository sesi dari database aktif (null bila DB tidak terbuka).
final readingSessionRepositoryProvider =
    FutureProvider<ReadingSessionRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return ReadingSessionRepository(db);
});

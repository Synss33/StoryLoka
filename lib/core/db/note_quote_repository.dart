import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/note_quote.dart';
import 'database_provider.dart';

/// Akses tabel `notes_quotes` (F-04). Append-only: konflik dihindari dengan
/// *insert-if-absent* (ID lokal sudah unik per-perangkat untuk data baru;
/// data server hanya ditambahkan bila belum ada).
class NoteQuoteRepository {
  NoteQuoteRepository(this._db);

  final Database _db;

  static const List<String> _columns = [
    'id',
    'book_id',
    'type',
    'content',
    'page',
    'created_at',
  ];

  Future<int> insert(NoteQuote note) =>
      _db.insert('notes_quotes', note.toRow());

  Future<List<NoteQuote>> listByBook(int bookId) async {
    final rows = await _db.query(
      'notes_quotes',
      columns: _columns,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(NoteQuote.fromRow).toList();
  }

  Future<List<NoteQuote>> listAll() async {
    final rows = await _db.query(
      'notes_quotes',
      columns: _columns,
      orderBy: 'created_at ASC',
    );
    return rows.map(NoteQuote.fromRow).toList();
  }

  /// Snapshot server: tambahkan baris yang belum dimiliki (idempoten).
  Future<void> applySnapshot(List<NoteQuote> serverNotes) async {
    for (final note in serverNotes) {
      if (note.id == null) continue;
      await _db.insert(
        'notes_quotes',
        note.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

/// Repository catatan/kutipan dari database aktif.
final noteQuoteRepositoryProvider =
    FutureProvider<NoteQuoteRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return NoteQuoteRepository(db);
});

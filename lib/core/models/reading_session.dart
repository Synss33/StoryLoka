/// Sesi membaca (tabel `reading_sessions`).
///
/// `duration_sec` dihitung dari selisih timestamp (stopwatch berbasis waktu,
/// bukan penghitung per detik — ketentuan dosen). Append-only, `updated_at`
/// dipakai untuk aturan *last-write-wins* sinkronisasi.
class ReadingSession {
  const ReadingSession({
    this.id,
    required this.bookId,
    required this.startTs,
    required this.durationSec,
    this.lastPage,
    this.note,
    required this.updatedAt,
  });

  final int? id;
  final int bookId;
  final int startTs;
  final int durationSec;
  final int? lastPage;
  final String? note;
  final int updatedAt;

  static ReadingSession fromRow(Map<String, Object?> row) => ReadingSession(
        id: row['id'] as int?,
        bookId: row['book_id'] as int,
        startTs: row['start_ts'] as int,
        durationSec: row['duration_sec'] as int,
        lastPage: row['last_page'] as int?,
        note: row['note'] as String?,
        updatedAt: row['updated_at'] as int,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'book_id': bookId,
        'start_ts': startTs,
        'duration_sec': durationSec,
        'last_page': lastPage,
        'note': note,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'book_id': bookId,
        'start_ts': startTs,
        'duration_sec': durationSec,
        'last_page': lastPage,
        'note': note,
        'updated_at': updatedAt,
      };
}

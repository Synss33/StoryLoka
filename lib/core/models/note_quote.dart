/// Catatan / kutipan (tabel `notes_quotes`, CHECK type IN ('note','quote')).
/// Append-only: konflik dihindari dengan insert-if-absent di server.
class NoteQuote {
  const NoteQuote({
    this.id,
    required this.bookId,
    required this.type,
    required this.content,
    this.page,
    required this.createdAt,
  });

  final int? id;
  final int bookId;

  /// 'note' atau 'quote'.
  final String type;
  final String content;
  final int? page;
  final int createdAt;

  static NoteQuote fromRow(Map<String, Object?> row) => NoteQuote(
        id: row['id'] as int?,
        bookId: row['book_id'] as int,
        type: row['type'] as String,
        content: row['content'] as String,
        page: row['page'] as int?,
        createdAt: row['created_at'] as int,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'book_id': bookId,
        'type': type,
        'content': content,
        'page': page,
        'created_at': createdAt,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'book_id': bookId,
        'type': type,
        'content': content,
        'page': page,
        'created_at': createdAt,
      };
}

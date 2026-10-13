/// Ulasan buku (tabel `reviews`). Append-only — dibuat sekali saat buku
/// ditandai "Selesai" (WF-05) dan dipicu ke blockchain (WF-08).
class Review {
  const Review({
    this.id,
    required this.bookId,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  final int? id;
  final int bookId;
  final double rating;
  final String? text;
  final int createdAt;

  static Review fromRow(Map<String, Object?> row) => Review(
        id: row['id'] as int?,
        bookId: row['book_id'] as int,
        rating: (row['rating'] as num).toDouble(),
        text: row['text'] as String?,
        createdAt: row['created_at'] as int,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'book_id': bookId,
        'rating': rating,
        'text': text,
        'created_at': createdAt,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'book_id': bookId,
        'rating': rating,
        'text': text,
        'created_at': createdAt,
      };
}

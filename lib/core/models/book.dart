/// Model buku (tabel `books` — deskripsi Bagian 5.2).
///
/// Waktu epoch millisecond (UTC); `deleted` = soft delete, `dirty` = belum
/// tersinkron (penanda antrean sinkron WF-03).
class Book {
  const Book({
    this.id,
    required this.userId,
    required this.title,
    this.author = '',
    this.publisher,
    this.year,
    this.isbn,
    this.genre,
    this.pages,
    this.cover,
    this.synopsis,
    this.status = 'unread',
    this.rating,
    this.price,
    this.startedAt,
    this.finishedAt,
    required this.updatedAt,
    this.deleted = false,
    this.dirty = true,
  });

  final int? id;
  final int userId;
  final String title;
  final String author;
  final String? publisher;
  final int? year;
  final String? isbn;
  final String? genre;
  final int? pages;
  final String? cover;
  final String? synopsis;

  /// `wishlist` / `unread` / `reading` / `completed` (CHECK di skema).
  final String status;
  final double? rating;
  final double? price;
  final int? startedAt;
  final int? finishedAt;
  final int updatedAt;
  final bool deleted;
  final bool dirty;

  static Book fromRow(Map<String, Object?> row) => Book(
        id: row['id'] as int?,
        userId: row['user_id'] as int,
        title: row['title'] as String,
        author: row['author'] as String? ?? '',
        publisher: row['publisher'] as String?,
        year: row['year'] as int?,
        isbn: row['isbn'] as String?,
        genre: row['genre'] as String?,
        pages: row['pages'] as int?,
        cover: row['cover'] as String?,
        synopsis: row['synopsis'] as String?,
        status: row['status'] as String? ?? 'unread',
        rating: (row['rating'] as num?)?.toDouble(),
        price: (row['price'] as num?)?.toDouble(),
        startedAt: row['started_at'] as int?,
        finishedAt: row['finished_at'] as int?,
        updatedAt: row['updated_at'] as int,
        deleted: row['deleted'] == 1,
        dirty: row['dirty'] == 1,
      );

  /// Bentuk payload JSON untuk `POST /sync` (key = nama kolom).
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'title': title,
        'author': author,
        'publisher': publisher,
        'year': year,
        'isbn': isbn,
        'genre': genre,
        'pages': pages,
        'cover': cover,
        'synopsis': synopsis,
        'status': status,
        'rating': rating,
        'price': price,
        'started_at': startedAt,
        'finished_at': finishedAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
      };

  /// Payload untuk tabel server (tanpa id lokal bila belum ada).
  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'title': title,
        'author': author,
        'publisher': publisher,
        'year': year,
        'isbn': isbn,
        'genre': genre,
        'pages': pages,
        'cover': cover,
        'synopsis': synopsis,
        'status': status,
        'rating': rating,
        'price': price,
        'started_at': startedAt,
        'finished_at': finishedAt,
        'updated_at': updatedAt,
        'deleted': deleted ? 1 : 0,
        'dirty': dirty ? 1 : 0,
      };

  /// Salinan dengan sebagian field diganti (dipakai layar edit & alur sesi).
  Book copyWith({
    int? id,
    int? userId,
    String? title,
    String? author,
    String? publisher,
    int? year,
    String? isbn,
    String? genre,
    int? pages,
    String? cover,
    String? synopsis,
    String? status,
    double? rating,
    double? price,
    int? startedAt,
    int? finishedAt,
    int? updatedAt,
    bool? deleted,
    bool? dirty,
  }) =>
      Book(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        author: author ?? this.author,
        publisher: publisher ?? this.publisher,
        year: year ?? this.year,
        isbn: isbn ?? this.isbn,
        genre: genre ?? this.genre,
        pages: pages ?? this.pages,
        cover: cover ?? this.cover,
        synopsis: synopsis ?? this.synopsis,
        status: status ?? this.status,
        rating: rating ?? this.rating,
        price: price ?? this.price,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        dirty: dirty ?? this.dirty,
      );
}

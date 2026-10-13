/// Blok hash chain "Proof of Reading" (tabel `blocks`, Bagian 5.7).
///
/// PK gabungan `(user_id, idx)`; `hash` = SHA-256 seluruh isi blok.
/// Append-only — server menyimpannya sebagai *anchor* pembanding rantai
/// (Bagian 5.7 mitigasi).
class Block {
  const Block({
    required this.idx,
    required this.userId,
    required this.timestamp,
    required this.bookId,
    required this.reviewHash,
    required this.finishedDate,
    required this.previousHash,
    required this.hash,
  });

  final int idx;
  final int userId;
  final int timestamp;
  final int bookId;
  final String reviewHash;
  final int finishedDate;
  final String previousHash;
  final String hash;

  static Block fromRow(Map<String, Object?> row) => Block(
        idx: row['idx'] as int,
        userId: row['user_id'] as int,
        timestamp: row['timestamp'] as int,
        bookId: row['book_id'] as int,
        reviewHash: row['review_hash'] as String,
        finishedDate: row['finished_date'] as int,
        previousHash: row['previous_hash'] as String,
        hash: row['hash'] as String,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'idx': idx,
        'user_id': userId,
        'timestamp': timestamp,
        'book_id': bookId,
        'review_hash': reviewHash,
        'finished_date': finishedDate,
        'previous_hash': previousHash,
        'hash': hash,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        'idx': idx,
        'user_id': userId,
        'timestamp': timestamp,
        'book_id': bookId,
        'review_hash': reviewHash,
        'finished_date': finishedDate,
        'previous_hash': previousHash,
        'hash': hash,
      };
}

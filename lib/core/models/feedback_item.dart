/// Kesan & saran mata kuliah Pemrograman Aplikasi Mobile (tabel `feedback`).
///
/// Penanda `synced` (0 = belum terkirim) dipakai antrean sinkron WF-03;
/// fitur SCR-10 dikerjakan di WF-04.
class FeedbackItem {
  const FeedbackItem({
    this.id,
    required this.userId,
    this.kesan,
    this.saran,
    required this.updatedAt,
    this.synced = false,
  });

  final int? id;
  final int userId;
  final String? kesan;
  final String? saran;
  final int updatedAt;
  final bool synced;

  static FeedbackItem fromRow(Map<String, Object?> row) => FeedbackItem(
        id: row['id'] as int?,
        userId: row['user_id'] as int,
        kesan: row['kesan'] as String?,
        saran: row['saran'] as String?,
        updatedAt: row['updated_at'] as int,
        synced: row['synced'] == 1,
      );

  /// Dari balasan `GET /feedback` server (`user_id` dipakai; `id` lokal
  /// dibiarkan null dan dibuat oleh tabel saat diterapkan).
  static FeedbackItem fromJson(Map<String, dynamic> json) => FeedbackItem(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        kesan: json['kesan'] as String?,
        saran: json['saran'] as String?,
        updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'user_id': userId,
        'kesan': kesan,
        'saran': saran,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'kesan': kesan,
        'saran': saran,
        'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };
}

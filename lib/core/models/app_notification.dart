/// Riwayat notifikasi — tabel `notifications` (SCR-14 / F-14 / WF-06).
class AppNotification {
  const AppNotification({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.ref,
    this.read = false,
    required this.createdAt,
  });

  final int? id;
  final int userId;

  /// `reminder` (pengingat harian) · `target` · `streak` · `certificate`.
  final String type;

  final String title;
  final String? body;

  /// Rute layar terkait saat notifikasi diketuk (mis. `/book/3`).
  final String? ref;

  final bool read;

  /// Epoch ms pembuatan.
  final int createdAt;

  static AppNotification fromRow(Map<String, Object?> row) => AppNotification(
        id: row['id'] as int?,
        userId: row['user_id'] as int,
        type: row['type'] as String,
        title: row['title'] as String,
        body: row['body'] as String?,
        ref: row['ref'] as String?,
        read: row['read'] == 1,
        createdAt: row['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toRow() {
    final row = <String, Object?>{
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'ref': ref,
      'read': read ? 1 : 0,
      'created_at': createdAt,
    };
    if (id != null) row['id'] = id;
    return row;
  }
}

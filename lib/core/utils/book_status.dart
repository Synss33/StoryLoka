/// Model status buku — konsisten di semua layar (dokumen desain Bagian 7).
enum BookStatus {
  wishlist('wishlist', 'Wishlist'),
  unread('unread', 'Belum Dibaca'),
  reading('reading', 'Sedang Dibaca'),
  completed('completed', 'Selesai');

  const BookStatus(this.code, this.label);

  /// Nilai yang disimpan di kolom `books.status`.
  final String code;

  /// Label bahasa Indonesia untuk badge/segmented control.
  final String label;

  /// Dari nilai kolom DB; nilai tak dikenal dianggap [unread].
  static BookStatus fromCode(String? code) => BookStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => BookStatus.unread,
      );
}

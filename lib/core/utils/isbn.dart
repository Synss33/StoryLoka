// Validasi ISBN untuk pemindai barcode (F-20 · SCR-07 · WF-05).
//
// Barcode EAN-13 di sampul belakang buku memuat ISBN-13 (bobot 1/3);
// sebagian penerbit masih mencetak ISBN-10 (bobot 10…1, `X` = 10).
// Keduanya diverifikasi terhadap cek digitnya sendiri.

/// Buang tanda pisah/spasi: `978-0-306-40615-7` → `9780306406157`.
String normalizeIsbn(String raw) => raw.replaceAll(RegExp(r'[-\s]'), '');

/// `true` bila [raw] adalah ISBN-13 atau ISBN-10 dengan cek digit valid.
bool isValidIsbn(String raw) {
  final code = normalizeIsbn(raw);
  if (code.length == 13) return _isValidIsbn13(code);
  if (code.length == 10) return _isValidIsbn10(code);
  return false;
}

bool _isValidIsbn13(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final digit = int.parse(code[i]);
    sum += i.isEven ? digit : digit * 3;
  }
  return (10 - sum % 10) % 10 == int.parse(code[12]);
}

bool _isValidIsbn10(String code) {
  if (!RegExp(r'^\d{9}[\dXx]$').hasMatch(code)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final ch = code[i].toUpperCase();
    final digit = ch == 'X' ? 10 : int.parse(ch);
    sum += (10 - i) * digit;
  }
  return sum % 11 == 0;
}

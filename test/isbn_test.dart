import 'package:flutter_test/flutter_test.dart';
import 'package:storyloka/core/utils/isbn.dart';

/// Validasi checksum ISBN (F-20 · WF-05) — dipakai pemindai barcode
/// sebelum lookup online agar barcode non-ISBN tidak memicu request.
void main() {
  group('normalizeIsbn', () {
    test('membuang strip dan spasi', () {
      expect(normalizeIsbn('978-0-306-40615-7'), '9780306406157');
      expect(normalizeIsbn(' 978 0306 406157 '), '9780306406157');
    });
  });

  group('isValidIsbn', () {
    test('ISBN-13 valid (cek digit 1/3)', () {
      expect(isValidIsbn('9780306406157'), isTrue);
      expect(isValidIsbn('978-0-306-40615-7'), isTrue,
          reason: 'ISBN tanda pisih tetap diterima setelah normalisasi');
    });

    test('ISBN-10 valid (cek digit mod 11, X = 10)', () {
      expect(isValidIsbn('0306406152'), isTrue);
      expect(isValidIsbn('080442957X'), isTrue);
    });

    test('menolak cek digit salah', () {
      expect(isValidIsbn('9780306406158'), isFalse);
      expect(isValidIsbn('0306406153'), isFalse);
    });

    test('menolak panjang / karakter salah', () {
      expect(isValidIsbn(''), isFalse);
      expect(isValidIsbn('123'), isFalse);
      expect(isValidIsbn('978030640615X'), isFalse,
          reason: 'X hanya sah sebagai cek digit ISBN-10 (10 digit)');
      expect(isValidIsbn('abcdefghijklm'), isFalse);
    });
  });
}

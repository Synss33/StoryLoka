import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Abstraksi pemindai barcode ISBN (F-20 · SCR-07).
///
/// Dipisah dari implementasi kamera (pola `PhotoPicker`, keputusan 23)
/// agar pengujian TC-30 dapat menyuntikkan hasil pindaian palsu tanpa
/// membuka `MobileScanner`/kamera asli di zona fake-async.
abstract class IsbnScanner {
  /// Buka layar pemindai; mengembalikan teks barcode, atau `null` bila
  /// pengguna membatalkan / izin kamera ditolak.
  Future<String?> scan(BuildContext context);
}

/// Provider abstraksi — di-override dengan fake saat pengujian.
final isbnScannerProvider = Provider<IsbnScanner>(
  (ref) => const GoRouterIsbnScanner(),
);

/// Implementasi produksi: membuka rute `/scan-isbn` (layar full-screen).
class GoRouterIsbnScanner implements IsbnScanner {
  const GoRouterIsbnScanner();

  @override
  Future<String?> scan(BuildContext context) =>
      context.push<String>('/scan-isbn');
}

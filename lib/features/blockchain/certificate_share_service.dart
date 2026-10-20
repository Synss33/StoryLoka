import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Berbagi gambar sertifikat bacaan (Bagian 5.7 — "Bagikan Sertifikat
/// sebagai gambar"). Dibungkus abstraksi agar pengujian dapat menyuntikkan
/// tiruan tanpa memanggil platform share (seam sama dengan
/// `NotificationService`/`PhotoPicker`).
abstract class CertificateShareService {
  Future<void> shareImage(Uint8List pngBytes, String fileName);
}

/// Implementasi asli memakai `share_plus` (menu berbagi sistem).
class SharePlusCertificateShare implements CertificateShareService {
  @override
  Future<void> shareImage(Uint8List pngBytes, String fileName) {
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }
}

/// Layanan berbagi sertifikat aktif (di-override saat pengujian).
final certificateShareServiceProvider = Provider<CertificateShareService>(
  (ref) => SharePlusCertificateShare(),
);

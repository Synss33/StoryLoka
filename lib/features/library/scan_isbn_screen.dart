import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// SCR-07 — Layar pemindai barcode ISBN (F-20 · WF-05).
///
/// Kamera full-screen dengan viewfinder overlay (dokumen desain SCR-07:
/// "izin kamera, viewfinder overlay"). Kode pertama yang terbaca
/// langsung menutup layar dan dikembalikan ke form SCR-07; batal/izin
/// ditolak mengembalikan `null`.
class ScanIsbnScreen extends StatefulWidget {
  const ScanIsbnScreen({super.key});

  @override
  State<ScanIsbnScreen> createState() => _ScanIsbnScreenState();
}

class _ScanIsbnScreenState extends State<ScanIsbnScreen> {
  final MobileScannerController _controller = MobileScannerController();

  /// Deteksi hanya diproses sekali agar layar tidak di-pop dua kali.
  bool _handled = false;

  void _return(String? value) {
    if (_handled || !mounted) return;
    _handled = true;
    context.pop(value);
  }

  @override
  void dispose() {
    // Dilepas eksplisit karena controller disuntikkan ke widget scanner.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Top bar gelap agar menyatu dengan preview kamera (layar opsional
      // di luar shell; Master Layout tetap 56dp).
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Pindai Barcode ISBN'),
        leading: IconButton(
          key: const ValueKey<String>('scan-cancel-top'),
          icon: const Icon(Icons.close),
          onPressed: () => _return(null),
        ),
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_handled) return;
          final value = capture.barcodes.isNotEmpty
              ? capture.barcodes.first.rawValue
              : null;
          if (value != null && value.isNotEmpty) _return(value);
        },
        errorBuilder: (context, error) =>
            _ScanErrorView(error: error, onCancel: () => _return(null)),
        overlayBuilder: (context, constraints) =>
            _Viewfinder(width: constraints.maxWidth * 0.78),
      ),
    );
  }
}

/// Kotak bidik di tengah layar + panduan singkat.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: 132,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6366F1), width: 3),
              borderRadius: AppRadius.mediumAll,
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          Text(
            'Arahkan kamera ke barcode ISBN\ndi belakang buku',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// State gagal kamera: izin ditolak dipisah agar pesannya kontekstual.
class _ScanErrorView extends StatelessWidget {
  const _ScanErrorView({required this.error, required this.onCancel});

  final MobileScannerException error;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              denied ? Icons.no_photography_outlined : Icons.error_outline,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Text(
              denied
                  ? 'Izin kamera diperlukan untuk memindai barcode. '
                      'Aktifkan izin kamera di pengaturan, lalu coba lagi.'
                  : 'Kamera tidak dapat dijalankan. Coba lagi.',
              textAlign: TextAlign.center,
              style: AppTypography.body2.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            FilledButton(onPressed: onCancel, child: const Text('Batal')),
          ],
        ),
      ),
    );
  }
}

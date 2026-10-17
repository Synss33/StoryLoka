import 'package:flutter/material.dart';

import '../../core/blockchain/hash_chain.dart';
import '../../core/models/block.dart';
import '../../core/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';

/// Kartu sertifikat "Proof of Reading" — ditampilkan di dialog pratinjau
/// (dilukis penuh sehingga `RepaintBoundary.toImage` dapat menangkapnya)
/// dan dibagikan sebagai PNG lewat [CertificateShareService].
class ReadingCertificate extends StatelessWidget {
  const ReadingCertificate({
    super.key,
    required this.book,
    required this.block,
    this.borderKey,
  });

  final Book book;
  final Block block;

  /// Key `RepaintBoundary` pembungkus — disuntikkan agar pemanggil dapat
  /// menangkap gambarnya (digunakan `BlockchainCard`).
  final Key? borderKey;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final finished = DateTime.fromMillisecondsSinceEpoch(block.finishedDate);

    return RepaintBoundary(
      key: borderKey,
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
          vertical: AppSpacing.cardGap + 4,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: p.success500, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 40, color: p.success500),
            const SizedBox(height: AppSpacing.micro),
            Text(
              'SERTIFIKAT BACAAN',
              style: AppTypography.h3.copyWith(color: p.success500),
            ),
            Text(
              'Storyloka · Proof of Reading (Hash Chain Lokal)',
              style: AppTypography.caption.copyWith(color: p.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Text(
              book.title,
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            if (book.author.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.micro),
              Text(
                book.author,
                style: AppTypography.body2.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.cardGap),
            Text(
              'Selesai dibaca · ${_formatTanggal(finished)}',
              style: AppTypography.body2,
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              'Blok #${block.idx} · ${HashChain.shortHash(block.hash)}',
              style: AppTypography.caption.copyWith(color: p.neutral500),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12 Okt 2026" — tanggal ringkas (konsisten dengan SCR-06).
String _formatTanggal(DateTime d) {
  const bulan = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}

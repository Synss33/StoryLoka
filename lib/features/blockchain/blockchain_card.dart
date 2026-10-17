import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/blockchain/hash_chain.dart';
import '../../core/db/block_repository.dart';
import '../../core/models/block.dart';
import '../../core/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';
import 'certificate_share_service.dart';
import 'reading_certificate.dart';

/// Kartu 🛡 Blockchain / Sertifikat di SCR-06 (F-12 / WF-08) — hanya
/// tampil pada buku berstatus *Selesai* (desain Bagian SCR-06):
/// badge `success-500`, nomor blok, hash SHA-256 terpotong,
/// `previous_hash`, tanggal selesai, **Validasi Rantai**, dan
/// **Bagikan Sertifikat** (gambar).
class BlockchainCard extends ConsumerStatefulWidget {
  const BlockchainCard({super.key, required this.book, this.block});

  final Book book;

  /// Blok milik buku ini; null bila buku selesai tapi bloknya belum ada
  /// (mis. data lama sebelum WF-08) → tombol dinonaktifkan.
  final Block? block;

  @override
  ConsumerState<BlockchainCard> createState() => _BlockchainCardState();
}

class _BlockchainCardState extends ConsumerState<BlockchainCard> {
  ChainValidation? _validation;
  bool _validating = false;
  bool _sharing = false;

  /// Key RepaintBoundary sertifikat di dialog pratinjau (ditangkap → PNG).
  final GlobalKey _certificateBorderKey = GlobalKey();

  /// Validasi rantai: ambil **seluruh** blok pengguna, hitung ulang hash +
  /// cocokkan rantai (workflow Bagian 3.4) → Valid / Tidak Valid (blok ke-n).
  Future<void> _validateChain() async {
    if (_validating) return;
    setState(() {
      _validating = true;
      _validation = null;
    });
    final repo = await ref.read(blockRepositoryProvider.future);
    final blocks =
        await repo?.listByUser(widget.book.userId) ?? const <Block>[];
    if (!mounted) return;
    setState(() {
      _validation = HashChain.validate(blocks);
      _validating = false;
    });
  }

  /// Bagikan Sertifikat: pratinjau dulu → tangkap `RepaintBoundary` →
  /// PNG → menu berbagi sistem (Bagian 5.7). Tangkap dilakukan **sebelum**
  /// dialog ditutup agar widget sertifikat masih ada di tree.
  Future<void> _showCertificate() async {
    final block = widget.block;
    if (block == null || _sharing) return;
    setState(() => _sharing = true);
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sertifikat Bacaan'),
        content: SingleChildScrollView(
          child: ReadingCertificate(
            book: widget.book,
            block: block,
            borderKey: _certificateBorderKey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tutup'),
          ),
          PrimaryButton(
            key: const ValueKey<String>('certificate-share'),
            label: 'Bagikan Gambar',
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final png = await _captureCertificatePng();
              if (png != null) {
                await _sharePng(png);
              }
              navigator.pop(true);
            },
          ),
        ],
      ),
    );
    if (mounted) setState(() => _sharing = false);
  }

  /// Menangkap isi [ReadingCertificate] menjadi byte PNG (pixelRatio 2.5).
  Future<Uint8List?> _captureCertificatePng() async {
    try {
      final boundary = _certificateBorderKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _sharePng(Uint8List png) async {
    final safeTitle = widget.book.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    try {
      await ref.read(certificateShareServiceProvider).shareImage(
            png,
            'sertifikat-${safeTitle.isEmpty ? 'bacaan' : safeTitle}.png',
          );
    } catch (_) {
      // Perangkat tanpa layanan berbagi — pratinjau tetap tampil.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final block = widget.block;
    final validation = _validation;

    return StorylokaCard(
      key: const ValueKey<String>('blockchain-card'),
      color: p.neutral100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: p.success500),
              const SizedBox(width: AppSpacing.micro),
              Expanded(
                child: Text(
                  'Terverifikasi (Hash Chain Lokal)',
                  style: AppTypography.h3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.grid),
          if (block == null)
            Text(
              'Blok sertifikat belum tersedia untuk buku ini. '
              'Tandai selesai dengan ulasan untuk menerbitkan sertifikat.',
              style: AppTypography.body2.copyWith(color: p.neutral500),
            )
          else ...[
            // Ringkas: nomor blok · hash terpotong · tanggal selesai.
            Text(
              'Blok #${block.idx}  ${HashChain.shortHash(block.hash)}  '
              '${_formatTanggalSingkat(block.finishedDate)}',
              key: const ValueKey<String>('blockchain-summary'),
              style: AppTypography.body2,
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              'previous_hash: ${HashChain.shortHash(block.previousHash)}',
              style: AppTypography.caption.copyWith(color: p.neutral500),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    key: const ValueKey<String>('validate-chain'),
                    label: 'Validasi Rantai',
                    onPressed: _validating ? null : _validateChain,
                  ),
                ),
                const SizedBox(width: AppSpacing.grid),
                Expanded(
                  child: SecondaryButton(
                    key: const ValueKey<String>('share-certificate'),
                    label: 'Bagikan Sertifikat',
                    onPressed: _sharing ? null : _showCertificate,
                  ),
                ),
              ],
            ),
            if (_validating) ...[
              const SizedBox(height: AppSpacing.grid),
              const LinearProgressIndicator(
                key: ValueKey<String>('chain-validating'),
              ),
            ],
            if (validation != null) ...[
              const SizedBox(height: AppSpacing.grid),
              Row(
                children: [
                  Icon(
                    validation.valid
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 18,
                    color: validation.valid ? p.success500 : p.danger500,
                  ),
                  const SizedBox(width: AppSpacing.micro),
                  Expanded(
                    child: Text(
                      validation.valid
                          ? 'Valid'
                          : 'Tidak Valid (blok ke-${validation.brokenIndex})',
                      key: ValueKey<String>(
                        validation.valid ? 'chain-valid' : 'chain-invalid',
                      ),
                      style: AppTypography.body2.copyWith(
                        color: validation.valid ? p.success500 : p.danger500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "12-10-2026" — tanggal ringkas sertifikat (dd-MM-yyyy).
String _formatTanggalSingkat(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  final bulan = d.month.toString().padLeft(2, '0');
  final hari = d.day.toString().padLeft(2, '0');
  return '$hari-$bulan-${d.year}';
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Sampul buku — dokumen desain Bagian 8: rasio 2:3, radius 8,
/// placeholder bila tidak ada gambar / gagal dimuat.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.path,
    this.width,
    this.borderRadius = AppRadius.smallAll,
  });

  /// `null`/kosong → placeholder; berawal `http(s):` → gambar jaringan;
  /// selain itu dianggap path berkas lokal (hasil kamera/galeri).
  final String? path;

  /// Lebar tampilan; tinggi mengikuti rasio 2:3.
  final double? width;

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cover = AspectRatio(
      aspectRatio: AppLayout.bookCoverRatio,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: _buildImage(context),
      ),
    );

    return width == null ? cover : SizedBox(width: width, child: cover);
  }

  Widget _buildImage(BuildContext context) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return const _CoverPlaceholder();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CoverPlaceholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _CoverPlaceholder(),
      );
    }

    return Image.file(
      File(value),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _CoverPlaceholder(),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Container(
      color: p.neutral100,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_outlined, color: p.neutral500, size: 28),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/models/book.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/book_status.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/status_badge.dart';

/// Baris rating ringkas ("bintang 4,5") — dipakai kartu & baris buku.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, this.rating, this.size = 12});

  final double? rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final value = rating;
    if (value == null) {
      return Text(
        '—',
        style: AppTypography.caption.copyWith(color: p.neutral500),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: p.warning500),
        const SizedBox(width: AppSpacing.micro),
        Text(
          value.toStringAsFixed(1).replaceAll('.', ','),
          style: AppTypography.caption.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Kartu buku grid 2 kolom SCR-03: cover 2:3, judul maks 2 baris,
/// penulis, rating, badge status (Bagian 6 SCR-03).
class BookCard extends StatelessWidget {
  const BookCard({
    super.key,
    required this.book,
    this.width,
    this.onTap,
    this.onLongPress,
  });

  final Book book;
  final double? width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final card = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.mediumAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(path: book.cover, width: width),
          const SizedBox(height: AppSpacing.grid),
          Text(
            book.title,
            style: AppTypography.h3.copyWith(color: p.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            book.author.isEmpty ? '—' : book.author,
            style: AppTypography.body2.copyWith(color: p.neutral500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.micro),
          Row(
            children: [
              RatingStars(rating: book.rating),
              const SizedBox(width: AppSpacing.grid),
              Flexible(
                child: StatusBadge(status: BookStatus.fromCode(book.status)),
              ),
            ],
          ),
        ],
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

/// Baris buku mode daftar (toggle Grid/List SCR-03 & hasil SCR-08).
class BookTile extends StatelessWidget {
  const BookTile({
    super.key,
    required this.book,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  final Book book;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.mediumAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.grid),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(path: book.cover, width: 56),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTypography.h3.copyWith(color: p.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Text(
                    book.author.isEmpty ? '—' : book.author,
                    style: AppTypography.body2.copyWith(color: p.neutral500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.micro),
                  Row(
                    children: [
                      RatingStars(rating: book.rating),
                      const SizedBox(width: AppSpacing.grid),
                      Flexible(
                        child: StatusBadge(
                          status: BookStatus.fromCode(book.status),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.grid),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

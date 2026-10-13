import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// State loading berbentuk shimmer — dokumen desain SCR-11.
///
/// Warna shimmer: `neutral-200` → `neutral-100` (pada mode gelap otomatis
/// menjadi `#475569` → `#334155`), siklus 1,2 detik. Bentuk: cover memakai
/// blok rasio 2:3, teks memakai garis selebar 70% dan 40%.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton.summary({super.key})
      : _preset = _SkeletonPreset.summary,
        count = 1;

  const LoadingSkeleton.list({super.key, this.count = 3})
      : _preset = _SkeletonPreset.list;

  const LoadingSkeleton.bookGrid({super.key, this.count = 4})
      : _preset = _SkeletonPreset.bookGrid;

  final _SkeletonPreset _preset;
  final int count;

  @override
  Widget build(BuildContext context) {
    return switch (_preset) {
      _SkeletonPreset.summary => const _SummarySkeleton(),
      // Dibungkus scroll agar aman bila ruang tinggi terbatas
      // (mis. area hasil pencarian di SCR-08) — tanpa overflow.
      _SkeletonPreset.list => SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < count; i++) ...[
                const _CardSkeleton(),
                if (i != count - 1)
                  const SizedBox(height: AppSpacing.cardGap),
              ],
            ],
          ),
        ),
      _SkeletonPreset.bookGrid => Wrap(
          spacing: AppSpacing.cardGap,
          runSpacing: AppSpacing.cardGap,
          children: [
            for (var i = 0; i < count; i++) const _BookGridItemSkeleton(),
          ],
        ),
    };
  }
}

enum _SkeletonPreset { summary, list, bookGrid }

/// Blok dasar shimmer; seluruh preset di atas dibangun dari widget ini.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.mediumAll,
  });

  final double? width;
  final double? height;
  final BorderRadius radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppLayout.shimmerDuration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(2 * _controller.value, 0),
              colors: [p.neutral200, p.neutral100, p.neutral200],
            ),
          ),
        );
      },
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(height: 96),
        SizedBox(height: AppSpacing.cardGap),
        SkeletonBox(width: 160, height: 16),
        SizedBox(height: AppSpacing.grid),
        SkeletonBox(height: 72),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover → blok rasio 2:3 (lebar 72dp).
        SkeletonBox(width: 72, height: 108, radius: AppRadius.smallAll),
        SizedBox(width: AppSpacing.cardGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Teks → garis lebar 70% dan 40%.
              SkeletonBox(width: 160, height: 14),
              SizedBox(height: AppSpacing.grid),
              SkeletonBox(width: 96, height: 12),
              SizedBox(height: AppSpacing.grid),
              SkeletonBox(width: 64, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookGridItemSkeleton extends StatelessWidget {
  const _BookGridItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 150, height: 225, radius: AppRadius.smallAll),
        SizedBox(height: AppSpacing.grid),
        SkeletonBox(width: 120, height: 14),
        SizedBox(height: AppSpacing.micro),
        SkeletonBox(width: 80, height: 12),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import 'converter_panel.dart';

/// SCR-04 — Explore: Peta (LBS), Konverter & Game.
///
/// WF-05 (F-17/F-18): segmen Konverter (mata uang + zona waktu, offline
/// friendly). Segmen Peta/LBS + shake → WF-06, segmen Game → WF-09.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

enum _Segment { peta, konverter, game }

class _ExploreScreenState extends State<ExploreScreen> {
  _Segment _segment = _Segment.konverter;
  bool _currencyMode = true;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Explore'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          SegmentedButton<_Segment>(
            segments: const [
              ButtonSegment(
                value: _Segment.peta,
                label: Text('Peta'),
                icon: Icon(Icons.map_outlined, size: 18),
              ),
              ButtonSegment(
                value: _Segment.konverter,
                label: Text('Konverter'),
                icon: Icon(Icons.currency_exchange_outlined, size: 18),
              ),
              ButtonSegment(
                value: _Segment.game,
                label: Text('Game'),
                icon: Icon(Icons.sports_esports_outlined, size: 18),
              ),
            ],
            selected: {_segment},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => _segment = selection.first),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          switch (_segment) {
            _Segment.peta => const ScreenPlaceholder(
                title: 'Peta Baca (LBS)',
                description:
                    'Peta sebaran bacaan, book club terdekat, dan aksi '
                    'shake (cek in lokasi) — diisi pada modul WF-06.',
                icon: Icons.map_outlined,
              ),
            _Segment.konverter => _buildConverter(p),
            _Segment.game => _buildGame(p),
          },
        ],
      ),
    );
  }

  Widget _buildConverter(AppPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ModeChip(
              label: 'Mata Uang',
              icon: Icons.payments_outlined,
              selected: _currencyMode,
              onTap: () => setState(() => _currencyMode = true),
            ),
            const SizedBox(width: AppSpacing.grid),
            _ModeChip(
              label: 'Zona Waktu',
              icon: Icons.schedule_outlined,
              selected: !_currencyMode,
              onTap: () => setState(() => _currencyMode = false),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.cardGap),
        if (_currencyMode)
          const CurrencyPanel()
        else
          const TimePanel(),
      ],
    );
  }

  Widget _buildGame(AppPalette p) {
    return StorylokaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book Trivia Challenge', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'Uji pengetahuan tentang buku-buku populer dalam putaran '
            'singkat — hadiah poin koleksi.',
            style: AppTypography.body2.copyWith(color: p.neutral500),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          TextButton.icon(
            key: const ValueKey<String>('play-trivia'),
            onPressed: () => context.push('/game'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Mainkan'),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardGap,
          vertical: AppSpacing.grid,
        ),
        decoration: BoxDecoration(
          color: selected ? p.primary500 : p.surface,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: selected ? p.primary500 : p.neutral200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? p.onPrimary : p.neutral500,
            ),
            const SizedBox(width: AppSpacing.micro),
            Text(
              label,
              style: AppTypography.body2.copyWith(
                color: selected ? p.onPrimary : p.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

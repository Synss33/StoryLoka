import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database_provider.dart';
import '../../core/db/game_score_repository.dart';
import '../../core/sensors/shake_discover.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../../features/auth/auth_controller.dart';
import 'converter_panel.dart';
import 'peta_panel.dart';

/// Data ringkas segmen Game SCR-04: skor tertinggi + total koin (WF-09).
class GameSummary {
  const GameSummary({this.bestScore, this.coins = 0, this.playCount = 0});

  final int? bestScore;
  final int coins;
  final int playCount;
}

/// Memuat rekor dari `game_scores` untuk kartu "Book Trivia Challenge".
final gameSummaryProvider = FutureProvider.autoDispose<GameSummary>((ref) {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return Future<GameSummary>.value(const GameSummary());
  return ref.watch(databaseProvider.future).then((db) async {
    if (db == null) return const GameSummary();
    final repo = GameScoreRepository(db);
    return GameSummary(
      bestScore: await repo.bestScore(userId),
      coins: await repo.totalCoins(userId),
      playCount: await repo.playCount(userId),
    );
  });
});

/// SCR-04 — Explore: Peta (LBS), Konverter & Game.
///
/// WF-05 (F-17/F-18): segmen Konverter (mata uang + zona waktu, offline
/// friendly). Segmen Peta/LBS + shake → WF-06, segmen Game → WF-09.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

enum _Segment { peta, konverter, game }

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  _Segment _segment = _Segment.konverter;
  bool _currencyMode = true;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return ShakeDiscoverWatcher(
      location: '/explore',
      child: Scaffold(
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
            _Segment.peta => const PetaPanel(), // SCR-04 — LBS (WF-06)
            _Segment.konverter => _buildConverter(p),
            _Segment.game => _buildGame(p),
          },
          ],
        ),
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
        if (_currencyMode) const CurrencyPanel() else const TimePanel(),
      ],
    );
  }

  Widget _buildGame(AppPalette p) {
    // Segmen Game SCR-04: kartu + skor tertinggi + koin → Mainkan (WF-09).
    final summary = ref.watch(gameSummaryProvider).value ?? const GameSummary();

    return StorylokaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book Trivia Challenge', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.micro),
          Text(
            'Uji pengetahuan tentang buku-buku populer dalam putaran '
            'singkat — jawaban benar menghasilkan koin.',
            style: AppTypography.body2.copyWith(color: p.neutral500),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 18, color: p.primary600),
              const SizedBox(width: AppSpacing.micro),
              Text(
                summary.bestScore == null
                    ? 'Belum ada skor'
                    : 'Rekor ${summary.bestScore}',
                key: const ValueKey<String>('game-best-score'),
                style: AppTypography.body2,
              ),
              const SizedBox(width: AppSpacing.cardGap),
              Icon(Icons.monetization_on_outlined, size: 18, color: p.primary600),
              const SizedBox(width: AppSpacing.micro),
              Text(
                '${summary.coins} koin',
                key: const ValueKey<String>('game-coins'),
                style: AppTypography.body2,
              ),
            ],
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
            Icon(icon, size: 16, color: selected ? p.onPrimary : p.neutral500),
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

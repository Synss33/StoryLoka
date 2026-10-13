import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/sensors/shake_discover.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_skeleton.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../library/book_tile.dart';
import '../library/library_data.dart';
import '../notifications/notifications_data.dart';
import '../profile/profile_data.dart';
import 'home_data.dart';

/// SCR-02 — Beranda, Ringkasan & Currently Reading (F-19, WF-05).
///
/// Header sapaan + lonceng + avatar; Reading Summary (`primary-500`);
/// kartu Currently Reading dengan tombol Mulai Baca → SCR-15; Aksi Cepat;
/// carousel My Collection → SCR-03. Shake sensor menyusul WF-06.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.of(context);
    final data = ref.watch(homeDataProvider);
    final user = ref.watch(profileDataProvider).value?.user;
    final name = (user?.name ?? 'Pembaca').split(' ').first;

    return ShakeDiscoverWatcher(
      location: '/',
      child: Scaffold(
        appBar: StorylokaTopBar(
          title: 'Halo, $name',
          leading: _HomeAvatar(photoPath: user?.photoPath, name: user?.name),
        actions: [
          IconButton(
            key: const ValueKey<String>('goto-notifications'),
            tooltip: 'Pusat Notifikasi',
            // Titik merah bila ada notifikasi belum dibaca (Bagian 6).
            icon: _NotificationBell(
              unread: ref.watch(unreadCountProvider).value ?? 0,
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeDataProvider),
          child: data.when(
            loading: () => const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: LoadingSkeleton.summary(),
            ),
            error: (error, _) => ErrorState(
              message: 'Gagal memuat ringkasan bacaan.',
              onRetry: () => ref.invalidate(homeDataProvider),
            ),
            data: (home) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // ---- Reading Summary (primary-500) ------------------------
                StorylokaCard(
                  color: p.primary500,
                  child: _SummaryCard(home: home),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // ---- Currently Reading ------------------------------------
                if (home.stats.currentlyReading != null) ...[
                  const _SectionTitle('Currently Reading'),
                  _CurrentlyReadingCard(home: home),
                ] else
                  StorylokaCard(
                    child: Row(
                      children: [
                        Icon(Icons.menu_book_outlined, color: p.neutral500),
                        const SizedBox(width: AppSpacing.cardGap),
                        Expanded(
                          child: Text(
                            'Belum ada buku yang sedang dibaca. '
                            'Pilih dari koleksi atau tambah buku baru.',
                            style: AppTypography.body2.copyWith(
                              color: p.neutral500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.cardGap),

                // ---- Aksi Cepat -------------------------------------------
                const _SectionTitle('Aksi Cepat'),
                const _QuickActions(),
                const SizedBox(height: AppSpacing.cardGap),

                // ---- My Collection ----------------------------------------
                Row(
                  children: [
                    const Expanded(
                      child: _SectionTitle('My Collection', withPadding: false),
                    ),
                    TextButton(
                      key: const ValueKey<String>('see-all-collection'),
                      onPressed: () => context.push('/library'),
                      child: const Text('Lihat semua'),
                    ),
                  ],
                ),
                if (home.collection.isEmpty)
                  Text(
                    'Belum ada buku. Tambahkan lewat tombol + di Library.',
                    style: AppTypography.body2.copyWith(color: p.neutral500),
                  )
                else
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: home.collection.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.cardGap),
                      itemBuilder: (context, index) {
                        final book = home.collection[index];
                        return SizedBox(
                          width: 110,
                          child: BookCard(
                            book: book,
                            width: 110,
                            onTap: () => context.push('/book/${book.id}'),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.cardGap),

                // ---- Status backend & DB (DoD WF-01) ----------------------
                _ConnectionStatus(
                  health: ref.watch(healthProvider),
                  database: ref.watch(databaseProvider),
                ),
                const SizedBox(height: AppSpacing.screenMargin),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.withPadding = true});

  final String text;
  final bool withPadding;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Padding(
      padding: withPadding
          ? const EdgeInsets.only(
              left: AppSpacing.micro,
              bottom: AppSpacing.grid,
            )
          : EdgeInsets.zero,
      child: Text(text, style: AppTypography.h2.copyWith(color: p.textPrimary)),
    );
  }
}

/// Kartu ringkasan: Dibaca · Selesai · streak · target bulan + progress bar.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.home});

  final HomeData home;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final stats = home.stats;
    final onPrimary = p.onPrimary;

    Widget cell(String value, String label) => Column(
      children: [
        Text(value, style: AppTypography.h1.copyWith(color: onPrimary)),
        Text(label, style: AppTypography.caption.copyWith(color: onPrimary)),
      ],
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cell('${stats.readingCount}', 'Dibaca')),
            Expanded(child: cell('${stats.completedCount}', 'Selesai')),
            Expanded(child: cell('🔥 ${stats.streakDays}', 'Hari Streak')),
          ],
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(
              child: Text(
                'Target bulan ini ${stats.monthlyDone}/${stats.monthlyTarget}',
                style: AppTypography.body2.copyWith(color: onPrimary),
              ),
            ),
            Text(
              '${(stats.monthlyProgress * 100).round()}%',
              style: AppTypography.body2.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.micro),
        ClipRRect(
          borderRadius: AppRadius.pillAll,
          child: LinearProgressIndicator(
            key: const ValueKey<String>('monthly-progress'),
            value: stats.monthlyProgress,
            minHeight: 8,
            backgroundColor: onPrimary.withValues(alpha: 0.25),
            color: onPrimary,
          ),
        ),
      ],
    );
  }
}

/// Kartu Currently Reading + tombol Mulai Baca → SCR-15.
class _CurrentlyReadingCard extends ConsumerWidget {
  const _CurrentlyReadingCard({required this.home});

  final HomeData home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.of(context);
    final book = home.stats.currentlyReading!;

    return StorylokaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookCover(path: book.cover, width: 64),
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
                  book.author,
                  style: AppTypography.body2.copyWith(color: p.neutral500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.grid),
                ClipRRect(
                  borderRadius: AppRadius.pillAll,
                  child: LinearProgressIndicator(
                    value: home.currentProgress,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  book.pages == null
                      ? 'Halaman ${home.currentLastPage}'
                      : '${(home.currentProgress * 100).round()}% · '
                            'halaman ${home.currentLastPage} dari ${book.pages}',
                  style: AppTypography.body2.copyWith(color: p.neutral500),
                ),
                const SizedBox(height: AppSpacing.grid),
                PrimaryButton(
                  key: const ValueKey<String>('start-reading'),
                  label: 'Mulai Baca',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push('/session?id=${book.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aksi cepat SCR-02: Koleksi · Wishlist · AI · Tambah · Cari.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.of(context);

    Widget action(String label, IconData icon, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mediumAll,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadius.mediumAll,
            border: Border.all(color: p.neutral200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: p.primary500),
              const SizedBox(height: AppSpacing.micro),
              Text(label, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        action('Koleksi', Icons.auto_stories_outlined, () {
          ref.read(libraryFilterProvider.notifier).setTab(LibraryTab.koleksi);
          context.push('/library');
        }),
        const SizedBox(width: AppSpacing.grid),
        action('Wishlist', Icons.favorite_outline, () {
          ref.read(libraryFilterProvider.notifier).setTab(LibraryTab.wishlist);
          context.push('/library');
        }),
        const SizedBox(width: AppSpacing.grid),
        action('AI', Icons.auto_awesome_outlined, () => context.push('/ai')),
        const SizedBox(width: AppSpacing.grid),
        action(
          'Tambah',
          Icons.add_box_outlined,
          () => context.push('/book/edit'),
        ),
        const SizedBox(width: AppSpacing.grid),
        action('Cari', Icons.search, () => context.push('/search')),
      ],
    );
  }
}

/// Ikon lonceng SCR-02 dengan titik merah bila ada notifikasi yang
/// belum dibaca (dokumen desain Bagian 6 SCR-02).
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (unread > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: p.danger500,
                shape: BoxShape.circle,
                border: Border.all(color: p.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// Avatar profil di top bar Beranda (ketuk → SCR-09 Profil).
class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({this.photoPath, this.name});

  final String? photoPath;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('home-avatar'),
      tooltip: 'Profil',
      padding: EdgeInsets.zero,
      onPressed: () => context.go('/profil'),
      icon: ProfileAvatar(photoPath: photoPath, name: name, radius: 16),
    );
  }
}

/// Catatan status panggilan `GET /health` dan pembukaan DB terenkripsi
/// (DoD WF-01 — tetap dipantau di SCR-02).
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.health, required this.database});

  final AsyncValue<HealthStatus> health;
  final AsyncValue<Object?> database;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final apiText = health.when(
      data: (value) => '${value.ok ? "✓" : "✗"} ${value.message}',
      error: (_, _) => '✗ Gagal memeriksa backend',
      loading: () => '… Memeriksa backend…',
    );
    final dbText = database.when(
      data: (db) => db == null
          ? '✗ Database terenkripsi belum terbuka'
          : '✓ Database terenkripsi terbuka',
      error: (_, _) => '✗ Database gagal dibuka',
      loading: () => '… Membuka database…',
    );
    final caption = AppTypography.body2.copyWith(color: p.neutral500);

    return Column(
      children: [
        Text('API: $apiText', style: caption, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.micro),
        Text('DB : $dbText', style: caption, textAlign: TextAlign.center),
      ],
    );
  }
}

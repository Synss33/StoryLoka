import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme_mode_provider.dart';
import '../../core/db/settings_repository.dart';
import '../../core/network/sync_service.dart';
import '../../core/notifications/notification_coordinator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/profile_avatar.dart';
import '../../core/widgets/storyloka_card.dart';
import '../../core/widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import 'profile_data.dart';
import 'profile_stats.dart';

/// SCR-09 — Profil, Pengaturan & Keamanan (F-02, F-03, F-07, WF-04).
///
/// Header berfoto → SCR-17; statistik ringkas; keamanan & sesi; notifikasi;
/// tema (auto/terang/gelap) yang dipersistensi; sinkronisasi manual.
/// **Tidak ada tombol Logout di sini** — logout ada di bottom nav.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: const StorylokaTopBar(title: 'Profil'),
      body: data.when(
        loading: () => const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gagal memuat profil.',
                  style: AppTypography.body2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.grid),
                TextButton(
                  onPressed: () => ref.invalidate(profileDataProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

/// Level pembaca sederhana dari jumlah buku selesai (keputusan WF-04).
String readerLevel(int booksRead) {
  if (booksRead >= 50) return 'Kutu Buku';
  if (booksRead >= 10) return 'Rutin';
  return 'Pemula';
}

String formatDateTime(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final ProfileData profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _syncing = false;

  Future<void> _toggleBiometric(bool enabled) async {
    final error = await ref
        .read(authControllerProvider.notifier)
        .setBiometricEnabled(enabled);
    ref.invalidate(profileDataProvider);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _toggleReminder(bool on) async {
    final userId = widget.profile.user?.id;
    final settings = await ref.read(settingsRepositoryProvider.future);
    if (userId != null) {
      await settings?.setReminder(userId, on: on);
      // Jadwalkan/batalkan pengingat sistem + izin kontekstual (F-14).
      await ref.read(notificationCoordinatorProvider).applyReminder(userId);
      if (on) {
        await ref.read(notificationServiceProvider).requestPermission();
      }
    }
    ref.invalidate(profileDataProvider);
  }

  Future<void> _pickReminderTime() async {
    final userId = widget.profile.user?.id;
    final current = widget.profile.settings?.reminderTime ?? '20:00';
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null || userId == null || !mounted) return;
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings?.setReminder(
      userId,
      on: widget.profile.settings?.reminderOn ?? true,
      time: '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}',
    );
    // Terapkan jam baru ke penjadwal sistem (F-14 — workflow 3.8).
    await ref.read(notificationCoordinatorProvider).applyReminder(userId);
    ref.invalidate(profileDataProvider);
  }

  Future<void> _toggleStreakNotify(bool on) async {
    final userId = widget.profile.user?.id;
    final settings = await ref.read(settingsRepositoryProvider.future);
    if (userId != null) {
      await settings?.setStreakNotify(userId, on);
    }
    ref.invalidate(profileDataProvider);
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final service = await ref.read(syncServiceProvider.future);
      final ok = await service?.syncNow() ?? false;
      ref.invalidate(profileDataProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Sinkronisasi selesai.'
              : 'Sinkronisasi gagal — periksa koneksi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final profile = widget.profile;
    final user = profile.user;
    final settings = profile.settings;
    final lastSync = settings?.lastSync;
    final stats = profile.stats;
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      children: [
        // ---- Header profil (ada gambar) → SCR-17 ------------------------
        StorylokaCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    photoPath: user?.photoPath,
                    name: user?.name,
                    radius: AppLayout.avatarLarge / 2,
                  ),
                  const SizedBox(width: AppSpacing.cardGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.micro),
                        Text(
                          user?.name ?? '—',
                          style: AppTypography.h3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.micro),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.email ?? '—',
                                style: AppTypography.body2
                                    .copyWith(color: p.neutral500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.grid),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.grid,
                                vertical: AppSpacing.micro,
                              ),
                              decoration: BoxDecoration(
                                color: p.primary50,
                                borderRadius: AppRadius.pillAll,
                              ),
                              child: Text(
                                readerLevel(stats.booksRead),
                                style: AppTypography.caption.copyWith(
                                  color: p.primary600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('edit-profile'),
                    tooltip: 'Edit profil',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.cardGap),
              _StatsRow(stats: stats),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Keamanan & Sesi --------------------------------------------
        _SectionTitle('Keamanan & Sesi'),
        StorylokaCard(
          child: Column(
            children: [
              if (profile.biometricSupported)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Login Biometrik'),
                  subtitle: Text(
                    'Verifikasi sidik/jenis saat membuka aplikasi',
                    style: AppTypography.caption.copyWith(color: p.neutral500),
                  ),
                  value: settings?.biometricEnabled ?? false,
                  onChanged: _toggleBiometric,
                ),
              if (profile.biometricSupported) const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, size: 20),
                title: const Text('Enkripsi Lokal (AES-256)'),
                trailing: Text(
                  'Aktif',
                  style: AppTypography.body2.copyWith(
                    color: p.success500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (profile.sessionExpiry != null) ...[
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule, size: 20),
                  title: const Text('Sesi berlaku hingga'),
                  trailing: Text(
                    formatDateTime(profile.sessionExpiry!),
                    style: AppTypography.caption.copyWith(color: p.neutral500),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Notifikasi (penjadwalan sistem → WF-06) ---------------------
        _SectionTitle('Notifikasi'),
        StorylokaCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengingat Harian'),
                subtitle: InkWell(
                  onTap: _pickReminderTime,
                  child: Text(
                    'Jam ${settings?.reminderTime ?? '20:00'}',
                    style: AppTypography.body2.copyWith(
                      color: p.primary600,
                    ),
                  ),
                ),
                value: settings?.reminderOn ?? true,
                onChanged: _toggleReminder,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifikasi target & streak'),
                value: settings?.streakNotify ?? true,
                onChanged: _toggleStreakNotify,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Tampilan: tema Otomatis / Terang / Gelap ---------------------
        _SectionTitle('Tampilan'),
        StorylokaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tema', style: AppTypography.body1),
              const SizedBox(height: AppSpacing.grid),
              SegmentedButton<StorylokaThemeMode>(
                segments: const <ButtonSegment<StorylokaThemeMode>>[
                  ButtonSegment(
                    value: StorylokaThemeMode.auto,
                    label: Text('Otomatis'),
                    icon: Icon(Icons.brightness_auto, size: 18),
                  ),
                  ButtonSegment(
                    value: StorylokaThemeMode.terang,
                    label: Text('Terang'),
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: StorylokaThemeMode.gelap,
                    label: Text('Gelap'),
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                  ),
                ],
                selected: <StorylokaThemeMode>{themeMode},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  final notifier = ref.read(themeModeProvider.notifier);
                  notifier.set(mode);
                  final userId = widget.profile.user?.id;
                  if (userId != null) notifier.persist(userId, mode);
                },
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Otomatis mengikuti sensor cahaya/sistem (Bagian 1.5).',
                style: AppTypography.caption.copyWith(color: p.neutral500),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // ---- Data: sinkronisasi manual -----------------------------------
        _SectionTitle('Data'),
        StorylokaCard(
          onTap: _syncing ? null : _syncNow,
          child: Row(
            children: [
              _syncing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_sync_outlined, size: 20),
              const SizedBox(width: AppSpacing.cardGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sinkronkan Sekarang',
                        style: AppTypography.body1),
                    Text(
                      lastSync == null
                          ? 'Terakhir: belum pernah'
                          : 'Terakhir: ${formatDateTime(lastSync)}',
                      style: AppTypography.caption
                          .copyWith(color: p.neutral500),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.neutral500),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.screenMargin),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.micro,
        bottom: AppSpacing.grid,
      ),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(
          color: p.neutral500,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    Widget cell(IconData icon, String value, String label) => Expanded(
          child: Column(
            children: [
              Icon(icon, size: 20, color: p.primary500),
              const SizedBox(height: AppSpacing.micro),
              Text(value, style: AppTypography.h3),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

    return Row(
      children: [
        cell(Icons.menu_book_outlined, '${stats.booksRead}', 'Buku'),
        cell(Icons.timer_outlined, '${stats.hoursRead}', 'Jam'),
        cell(Icons.verified_outlined, '${stats.certificates}', 'Sertifikat'),
        cell(Icons.monetization_on_outlined, '${stats.coins}', 'Koin'),
      ],
    );
  }
}

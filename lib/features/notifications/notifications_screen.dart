import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/db/notification_repository.dart';
import '../../core/models/app_notification.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/screen_placeholder.dart';
import '../../core/widgets/top_bar.dart';
import '../auth/auth_controller.dart';
import 'notifications_data.dart';

/// SCR-14 — Pusat Notifikasi (F-14 / WF-06, dokumen desain Bagian 6).
///
/// Daftar riwayat (ikon, judul, waktu, titik belum dibaca) + aksi
/// **Tandai Semua Dibaca**; ketuk → tandai terbaca + buka layar terkait
/// (SCR-06 / SCR-15 / SCR-14).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref) async {
    final userId = ref.read(authControllerProvider).userId;
    if (userId == null) return;
    final repo = await ref.read(notificationRepositoryProvider.future);
    await repo?.markAllRead(userId);
    ref
      ..invalidate(notificationsListProvider)
      ..invalidate(unreadCountProvider);
  }

  Future<void> _open(WidgetRef ref, AppNotification item) async {
    if (item.id != null) {
      final repo = await ref.read(notificationRepositoryProvider.future);
      await repo?.markRead(item.id!);
      ref
        ..invalidate(notificationsListProvider)
        ..invalidate(unreadCountProvider);
    }
    final route = item.ref;
    if (route != null && route.isNotEmpty) {
      appRouter.push(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsListProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: StorylokaTopBar(
        title: 'Pusat Notifikasi',
        actions: [
          if (unread > 0)
            TextButton(
              key: const ValueKey<String>('mark-all-read'),
              onPressed: () => _markAllRead(ref),
              child: const Text('Tandai Semua Dibaca'),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => Center(
          child: TextButton(
            key: const ValueKey<String>('retry-notifications'),
            onPressed: () => ref.invalidate(notificationsListProvider),
            child: const Text('Coba Lagi'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const ScreenPlaceholder(
                title: 'Belum Ada Notifikasi',
                description:
                    'Pengingat harian, target/streak, dan sertifikat akan '
                    'tercatat di sini.',
                icon: Icons.notifications_none,
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.grid,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.micro),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _NotificationTile(
                    item: item,
                    onTap: () => _open(ref, item),
                  );
                },
              ),
      ),
    );
  }
}

/// Satu baris riwayat: ikon tipe · judul · waktu · titik belum dibaca.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final unread = !item.read;

    return ListTile(
      key: ValueKey<String>('notification-${item.id ?? item.title}'),
      leading: Icon(
        _iconFor(item.type),
        color: unread ? p.primary500 : p.neutral500,
      ),
      title: Text(
        item.title,
        style: AppTypography.body1.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
          color: unread ? p.textPrimary : p.neutral500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body != null && item.body!.isNotEmpty)
            Text(
              item.body!,
              style: AppTypography.caption.copyWith(color: p.neutral500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 2),
          Text(
            formatWaktu(item.createdAt),
            style: AppTypography.caption.copyWith(color: p.neutral500),
          ),
        ],
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: p.danger500,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Ikon per tipe notifikasi (SCR-14: pengingat, target/streak, sertifikat).
IconData _iconFor(String type) => switch (type) {
      'reminder' => Icons.notifications_active_outlined,
      'target' => Icons.flag_outlined,
      'streak' => Icons.local_fire_department_outlined,
      'certificate' => Icons.verified_outlined,
      _ => Icons.notifications_outlined,
    };

/// Waktu ramah: `14:35` bila hari ini, selain itu `12 Okt, 14:35`.
String formatWaktu(int epochMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  final sameDay =
      d.year == now.year && d.month == now.month && d.day == now.day;
  if (sameDay) return '$hh:$mm';
  return '${d.day} ${months[d.month - 1]}, $hh:$mm';
}

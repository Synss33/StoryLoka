import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/notification_repository.dart';
import '../../core/models/app_notification.dart';
import '../auth/auth_controller.dart';

/// Riwayat notifikasi milik pengguna aktif — SCR-14 (F-14 / WF-06),
/// terbaru di atas.
final notificationsListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return const <AppNotification>[];
  final repo = await ref.watch(notificationRepositoryProvider.future);
  if (repo == null) return const <AppNotification>[];
  return repo.list(userId);
});

/// Jumlah notifikasi belum dibaca — titik merah lonceng SCR-02
/// (dokumen desain Bagian 6 SCR-02).
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return 0;
  final repo = await ref.watch(notificationRepositoryProvider.future);
  if (repo == null) return 0;
  return repo.unreadCount(userId);
});

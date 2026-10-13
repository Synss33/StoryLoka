import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../db/database_provider.dart';
import '../db/notification_repository.dart';
import '../db/settings_repository.dart';
import '../models/app_notification.dart';
import '../utils/reading_stats.dart';
import 'notification_service.dart';

const String _reminderTitle = 'Pengingat Membaca';
const String _reminderBody =
    'Saatnya membaca hari ini — jaga streak-mu tetap menyala!';

/// Penghubung notifikasi sistem ↔ riwayat lokal ↔ navigasi (F-14 / WF-06).
///
/// * pengingat harian → `scheduleDaily` (timezone-aware, workflow 3.8);
/// * event target/streak/sertifikat → notifikasi satu kali + tabel
///   `notifications`;
/// * ketuk notifikasi → tandai terbaca + buka layar terkait
///   (SCR-06 / SCR-15 / SCR-14);
/// * saat sesi valid → rekam pengingat yang sudah lewat hari ini agar
///   riwayat SCR-14 tetap lengkap walau aplikasi dibuka setelah jamnya.
class NotificationCoordinator {
  NotificationCoordinator(this._ref);

  final Ref _ref;

  /// Id jadwal pengingat harian (satu per perangkat).
  static const int reminderId = 1;

  bool _initialized = false;

  /// Mendaftarkan callback ketuk notifikasi (sekali per proses).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _ref.read(notificationServiceProvider).initialize(_onSelect);
    } catch (_) {
      // Layanan notifikasi tidak tersedia — riwayat lokal tetap jalan.
    }
  }

  /// Dipanggil saat splash menemukan sesi valid: rekam pengingat yang
  /// sudah lewat hari ini (tanpa menampilkan ulang notifikasi sistem).
  Future<void> onSessionStart(int userId) async {
    try {
      await init();
      await syncMissedReminder(userId);
    } catch (_) {
      // Riwayat pengingat gagal direkam — tidak boleh mengganggu sesi.
    }
  }

  Future<void> syncMissedReminder(int userId) async {
    final settingsRepo = await _ref.read(settingsRepositoryProvider.future);
    final settings = await settingsRepo?.read(userId);
    if (settings == null || !settings.reminderOn) return;

    final due = _todayAt(settings.reminderTime);
    if (due == null || !DateTime.now().isAfter(due)) return;

    final repo = await _ref.read(notificationRepositoryProvider.future);
    if (repo == null) return;
    if (await repo.existsToday(userId, 'reminder')) return;
    await repo.insert(
      AppNotification(
        userId: userId,
        type: 'reminder',
        title: _reminderTitle,
        body: _reminderBody,
        ref: '/notifications',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Menerapkan setelan pengingat ke penjadwal sistem — dipanggil SCR-09
  /// saat switch/jam berubah (seam yang sama dipakai pengujian TC-23).
  Future<void> applyReminder(int userId) async {
    try {
      await init();
      final settingsRepo = await _ref.read(settingsRepositoryProvider.future);
      final settings = await settingsRepo?.read(userId);
      if (settings == null) return;

      final service = _ref.read(notificationServiceProvider);
      if (!settings.reminderOn) {
        await service.cancel(reminderId);
        return;
      }

      final parts = settings.reminderTime.split(':');
      await service.scheduleDaily(
        id: reminderId,
        hour: int.tryParse(parts.first) ?? 20,
        minute: int.tryParse(parts.length > 1 ? parts.last : '0') ?? 0,
        title: _reminderTitle,
        body: _reminderBody,
        payload: 'reminder|$userId|/notifications',
      );
    } catch (_) {
      // Penjadwalan gagal — pengguna dapat mencoba ulang dari Profil.
    }
  }

  /// Event target/streak/sertifikat → notifikasi sistem + riwayat lokal.
  ///
  /// [route] dibuka saat notifikasi diketuk; [type] dipakai untuk dedupe
  /// per hari (sertifikat biasanya sekali — `dedupePerDay: false`).
  Future<void> emitEvent({
    required int userId,
    required String type,
    required String title,
    required String body,
    String route = '/notifications',
    bool dedupePerDay = true,
  }) async {
    try {
      await init();
      final repo = await _ref.read(notificationRepositoryProvider.future);
      if (repo == null) return;
      if (dedupePerDay && await repo.existsToday(userId, type)) return;

      await repo.insert(
        AppNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          ref: route,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await _ref.read(notificationServiceProvider).show(
            NotificationPayload(
              id: _idFor(type),
              title: title,
              body: body,
              payload: '$type|$userId|$route',
            ),
          );
    } catch (_) {
      // Gagal menampilkan — riwayat lokal tetap dicoba pada panggilan
      // berikutnya.
    }
  }

  /// Notifikasi target bulanan & streak setelah sesi disimpan
  /// (menghormati toggle "Notifikasi target & streak" di SCR-09).
  Future<void> notifySessionMilestones(int userId) async {
    try {
      final settingsRepo = await _ref.read(settingsRepositoryProvider.future);
      final settings = await settingsRepo?.read(userId);
      if (settings == null || !settings.streakNotify) return;

      final db = await _ref.read(databaseProvider.future);
      if (db == null) return;
      final stats = await ReadingStats.load(db, userId);

      if (stats.monthlyTarget > 0 && stats.monthlyDone >= stats.monthlyTarget) {
        await emitEvent(
          userId: userId,
          type: 'target',
          title: 'Target Bulanan Tercapai',
          body: '${stats.monthlyDone} dari ${stats.monthlyTarget} buku '
              'selesai bulan ini. Kerja bagus!',
        );
      }
      if (stats.streakDays > 0 && stats.streakDays % 7 == 0) {
        await emitEvent(
          userId: userId,
          type: 'streak',
          title: 'Streak ${stats.streakDays} Hari',
          body: 'Kamu membaca ${stats.streakDays} hari berturut-turut. '
              'Pertahankan!',
        );
      }
    } catch (_) {
      // Milestone gagal dihitung — sesi tetap tersimpan normal.
    }
  }

  /// Waktu pengingat hari ini (bila jamnya sudah lewat → hari ini juga
  /// masih dianggap "lewat"); `null` bila format jam tidak dikenal.
  static DateTime? _todayAt(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first);
    final minute = int.tryParse(parts.length > 1 ? parts.last : '');
    if (hour == null || minute == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static int _idFor(String type) => switch (type) {
        'reminder' => reminderId,
        'target' => 2,
        'streak' => 3,
        'certificate' => 4,
        _ => 5,
      };

  /// Callback ketuk notifikasi sistem: catat pengingat yang belum ada di
  /// riwayat, tandai terbaca, lalu buka rute layar terkait
  /// (`type|userId|rute`).
  Future<void> _onSelect(int id, String? payload) async {
    final parts = (payload ?? '').split('|');
    if (parts.length < 3) return;
    final type = parts[0];
    final userId = int.tryParse(parts[1]);
    final route = parts[2];

    if (userId != null) {
      try {
        final repo = await _ref.read(notificationRepositoryProvider.future);
        if (repo != null) {
          // Pengingat yang diketak langsung tercatat bila belum ada hari ini
          // (yang tidak diketak menyusul lewat pemeriksaan saat splash).
          if (type == 'reminder' && !await repo.existsToday(userId, type)) {
            await repo.insert(
              AppNotification(
                userId: userId,
                type: type,
                title: _reminderTitle,
                body: _reminderBody,
                ref: '/notifications',
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
          await repo.markTypeRead(userId, type);
        }
      } catch (_) {
        // Riwayat tidak terjangkau — navigasi tetap dilakukan.
      }
    }
    if (route.isEmpty) return;
    try {
      appRouter.push(route);
    } catch (_) {
      // Router belum siap (mis. sebelum aplikasi terpasang).
    }
  }
}

/// Koordinator notifikasi aktif (dibaca SCR-09, splash, sesi, SCR-14).
final notificationCoordinatorProvider =
    Provider<NotificationCoordinator>((ref) {
  return NotificationCoordinator(ref);
});

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifikasi sistem satu baris (judul, isi, payload ketuk).
class NotificationPayload {
  const NotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final String title;
  final String body;

  /// Data yang dikembalikan saat notifikasi diketuk
  /// (format `type|userId|rute`).
  final String? payload;
}

/// Layanan notifikasi sistem yang dapat disuntikkan (F-14 / WF-06) —
/// pengujian TC-23 menyuntikkan tiruan yang merekam pemanggilan.
abstract class NotificationService {
  /// Mendaftarkan callback ketuk notifikasi (sekali saat startup).
  Future<void> initialize(void Function(int id, String? payload) onSelect);

  /// Izin notifikasi (Android 13+ `POST_NOTIFICATIONS`, iOS) — diminta
  /// secara kontekstual (desain SCR-09/SCR-14).
  Future<void> requestPermission();

  /// Menampilkan notifikasi satu kali sekarang (event target/streak/
  /// sertifikat).
  Future<void> show(NotificationPayload notification);

  /// Menjadwalkan pengingat harian berulang (timezone-aware) — workflow 3.8.
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> cancel(int id);
}

/// Implementasi asli memakai `flutter_local_notifications`.
///
/// Semua panggilan platform dibungkus try/catch dan hanya berjalan di
/// Android/iOS — di host pengembangan/uji tidak ada channel yang
/// dipanggil agar tidak menggantung.
class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezonesReady = false;

  static const String channelId = 'pengingat_storyloka';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      'Pengingat Storyloka',
      channelDescription:
          'Pengingat membaca harian, target bulanan, dan streak',
      importance: Importance.high,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize(
    void Function(int id, String? payload) onSelect,
  ) async {
    if (!_supported || _initialized) return;
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          onSelect(response.id ?? 0, response.payload);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          'Pengingat Storyloka',
          description:
              'Pengingat membaca harian, target bulanan, dan streak',
          importance: Importance.high,
        ),
      );
    } catch (_) {
      // Perangkat tanpa layanan notifikasi — fitur dilewati.
    }
  }

  @override
  Future<void> requestPermission() async {
    if (!_supported) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Izin ditolak atau platform tanpa layanan.
    }
  }

  @override
  Future<void> show(NotificationPayload notification) async {
    if (!_supported) return;
    try {
      await _plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: _details,
        payload: notification.payload,
      );
    } catch (_) {
      // Gagal menampilkan — riwayat lokal tetap tersimpan.
    }
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_supported) return;
    try {
      await _ensureTimezone();
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (_) {
      // Jadwal tidak dapat dibuat — pengingat tetap lewat event lokal.
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Tidak ada jadwal untuk dibatalkan.
    }
  }

  /// Zona waktu perangkat; fallback Asia/Jakarta bila tidak terbaca.
  Future<void> _ensureTimezone() async {
    if (_timezonesReady) return;
    _timezonesReady = true;
    try {
      tz_data.initializeTimeZones();
    } catch (_) {
      return;
    }
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        // Tetap memakai zona default (UTC).
      }
    }
  }
}

/// Layanan notifikasi aktif (di-override dengan tiruan saat pengujian).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});

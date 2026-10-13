import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/db/notification_repository.dart';
import 'package:storyloka/core/db/settings_repository.dart';
import 'package:storyloka/core/models/app_notification.dart';
import 'package:storyloka/core/notifications/notification_coordinator.dart';
import 'package:storyloka/core/notifications/notification_service.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';

/// Biometrik palsu agar layar tidak menggantung (lihat widget_test.dart).
class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Notifikasi sistem tiruan — merekam jadwal/event dan bisa "diketuk"
/// lewat [deliver] (simulasi OS, TC-23).
class _FakeNotificationService implements NotificationService {
  void Function(int id, String? payload)? onSelect;

  NotificationPayload? shown;
  int? scheduledId;
  int? scheduledHour;
  int? scheduledMinute;
  String? scheduledPayload;
  bool permissionRequested = false;
  bool delivered = false;
  final List<int> cancelled = <int>[];

  @override
  Future<void> initialize(void Function(int, String?) callback) async {
    onSelect = callback;
  }

  @override
  Future<void> requestPermission() async {
    permissionRequested = true;
  }

  @override
  Future<void> show(NotificationPayload notification) async {
    shown = notification;
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
    scheduledId = id;
    scheduledHour = hour;
    scheduledMinute = minute;
    scheduledPayload = payload;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  /// Simulasi OS: pengingat tampil lalu diketuk pengguna.
  void deliver() {
    delivered = onSelect != null;
    onSelect?.call(scheduledId ?? 0, scheduledPayload);
  }
}

/// Test case WF-06 notifikasi: TC-23 (set jam +1 menit → dijadwalkan &
/// tercatat di SCR-14) plus aksi Tandai Semua Dibaca.
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late int userId;
  late _FakeNotificationService fake;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    fake = _FakeNotificationService();
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf06_notif');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
  });

  tearDown(() async {
    PasswordHasher.iterations = PasswordHasher.defaultIterations;
    try {
      await db.close();
    } catch (_) {}
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final user = await tester.runAsync(
      () => UserRepository(db).register(
        name: 'Pengguna Uji',
        email: 'uji@example.com',
        password: 'KataSandi!123',
      ),
    );
    userId = user?.id ?? 1;
    store = InMemoryAuthStore()
      ..session = SessionRules.create(userId);
    appRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWith((ref) async => db),
          biometricServiceProvider.overrideWithValue(_NoBiometric()),
          notificationServiceProvider.overrideWithValue(fake),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TC-23: set jam +1 menit → dijadwalkan & tercatat di SCR-14',
      (tester) async {
    await pumpApp(tester);

    // Setelan SCR-09: jam pengingat +1 menit dari sekarang (workflow test
    // case TC-23), lalu terapkan lewat seam yang sama seperti Profil.
    final target = DateTime.now().add(const Duration(minutes: 1));
    final time =
        '${target.hour.toString().padLeft(2, '0')}:${target.minute.toString().padLeft(2, '0')}';
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorylokaApp)),
      );
      final settings = await container.read(settingsRepositoryProvider.future);
      await settings?.setReminder(userId, on: true, time: time);
      await container
          .read(notificationCoordinatorProvider)
          .applyReminder(userId);
    });

    expect(fake.scheduledHour, target.hour, reason: 'jadwal = jam yang diset');
    expect(fake.scheduledMinute, target.minute);
    expect(fake.scheduledPayload, 'reminder|$userId|/notifications');

    // Hapus riwayat uji sebelumnya agar hanya pengingat ini yang dihitung.
    await tester.runAsync(() => db.delete('notifications'));

    // Simulasi OS: pengingat fires lalu diketuk → tercatat & SCR-14 terbuka.
    await tester.runAsync(() async {
      fake.deliver();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(fake.delivered, isTrue, reason: 'notifikasi sistem tampil');
    expect(appRouter.state.matchedLocation, '/notifications');
    expect(find.text('Pengingat Membaca'), findsOneWidget);

    final rows = await tester.runAsync(
      () => db.query(
        'notifications',
        where: 'user_id = ? AND type = ?',
        whereArgs: <Object?>[userId, 'reminder'],
      ),
    );
    expect(rows, hasLength(1), reason: 'tercatat di tabel notifications');
    expect(rows!.first['title'], 'Pengingat Membaca');
  });

  testWidgets('SCR-14: Tandai Semua Dibaca menghapus titik belum dibaca',
      (tester) async {
    await pumpApp(tester);

    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(() async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorylokaApp)),
      );
      final repo = await container.read(notificationRepositoryProvider.future);
      await repo?.insert(
        AppNotification(
          userId: userId,
          type: 'target',
          title: 'Target Bulanan Tercapai',
          body: '5 dari 5 buku selesai.',
          ref: '/notifications',
          createdAt: now,
        ),
      );
      await repo?.insert(
        AppNotification(
          userId: userId,
          type: 'streak',
          title: 'Streak 7 Hari',
          body: 'Pertahankan!',
          ref: '/notifications',
          createdAt: now - 1000,
        ),
      );
    });

    appRouter.push('/notifications');
    await tester.pumpAndSettle();
    expect(find.text('Target Bulanan Tercapai'), findsOneWidget);
    expect(find.text('Streak 7 Hari'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('mark-all-read')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('mark-all-read')));
    await tester.pumpAndSettle();

    // Aksi hilang karena tidak ada lagi yang belum dibaca.
    expect(find.byKey(const ValueKey<String>('mark-all-read')), findsNothing);
    final unread = await tester.runAsync(
      () => db.query(
        'notifications',
        where: 'user_id = ? AND read = 0',
        whereArgs: <Object?>[userId],
      ),
    );
    expect(unread, isEmpty);
  });
}

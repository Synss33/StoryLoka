import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/models/book.dart';
import 'package:storyloka/core/sensors/sensor_streams.dart';
import 'package:storyloka/core/sensors/shake_detector.dart';
import 'package:storyloka/core/sensors/shake_discover.dart';
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

/// Test case WF-06 sensor: TC-19 (shake → buku acak Wishlist + haptic)
/// dan TC-20 (diam/berjalan tidak salah picu).
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late int userId;
  late StreamController<AccelSample> accel;
  var hapticCalls = 0;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    hapticCalls = 0;
    accel = StreamController<AccelSample>.broadcast();
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf06');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
  });

  tearDown(() async {
    PasswordHasher.iterations = PasswordHasher.defaultIterations;
    if (!accel.isClosed) await accel.close();
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
          accelSampleStreamProvider.overrideWithValue(accel.stream),
          shakeHapticProvider.overrideWithValue(() => hapticCalls++),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    appRouter.go('/');
    await tester.pumpAndSettle();
  }

  /// Menanam satu buku berstatus wishlist (di luar zona fake-async).
  Future<int> seedWishlist(WidgetTester tester, String title) async {
    final id = await tester.runAsync(
      () => BookRepository(db).insert(
        Book(
          userId: userId,
          title: title,
          author: 'Penulis Uji',
          genre: 'Fiksi',
          year: 2020,
          rating: 5,
          pages: 300,
          status: 'wishlist',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    return id ?? 0;
  }

  /// Dua guncangan kuat dalam jendela 600 ms (workflow 3.6).
  Future<void> feedShake(WidgetTester tester, {double magnitude = 15}) async {
    final t0 = DateTime(2026, 1, 1, 8);
    accel
      ..add(AccelSample(magnitude: magnitude, at: t0))
      ..add(
        AccelSample(
          magnitude: magnitude,
          at: t0.add(const Duration(milliseconds: 250)),
        ),
      );
    await tester.pump();
  }

  /// Memompa sampai modal shake muncul (maks 3 dtk).
  Future<bool> modalVisible(WidgetTester tester) async {
    const modal = ValueKey<String>('shake-modal');
    for (var i = 0; i < 30 && find.byKey(modal).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return find.byKey(modal).evaluate().isNotEmpty;
  }

  testWidgets(
      'TC-19: shake di Beranda → modal buku acak Wishlist + haptic',
      (tester) async {
    await pumpApp(tester);
    final bookId = await seedWishlist(tester, 'Buku Wishlist Acak');
    expect(bookId, greaterThan(0));

    await feedShake(tester);

    expect(
      await modalVisible(tester),
      isTrue,
      reason: 'shake 2 guncangan harus membuka modal (Bagian 4)',
    );
    expect(
      find.byKey(const ValueKey<String>('shake-book-title')),
      findsOneWidget,
    );
    expect(find.text('Buku Wishlist Acak'), findsOneWidget);
    expect(hapticCalls, 1, reason: 'shake memicu haptic feedback');

    // Modal → Lihat Detail → SCR-06.
    await tester.tap(find.byKey(const ValueKey<String>('shake-open')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(appRouter.state.matchedLocation, '/book/$bookId');
  });

  testWidgets(
      'TC-20: diam / berjalan / guncangan tunggal tidak salah picu',
      (tester) async {
    await pumpApp(tester);
    final t0 = DateTime(2026, 1, 1, 9);

    // Diam / berjalan: magnitudo jauh di bawah ambang 12 m/s².
    for (var i = 0; i < 10; i++) {
      accel.add(
        AccelSample(
          magnitude: 3.2,
          at: t0.add(Duration(milliseconds: i * 100)),
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey<String>('shake-modal')), findsNothing);
    expect(hapticCalls, 0);

    // Guncangan tunggal (tidak 2 kali dalam 600 ms) → tidak memicu.
    accel.add(AccelSample(magnitude: 15, at: t0.add(const Duration(seconds: 3))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey<String>('shake-modal')), findsNothing);

    // Dua guncangan tapi berjauhan (> 600 ms) → di luar jendela.
    final t1 = t0.add(const Duration(seconds: 6));
    accel
      ..add(AccelSample(magnitude: 15, at: t1))
      ..add(
        AccelSample(
          magnitude: 15,
          at: t1.add(const Duration(milliseconds: 800)),
        ),
      );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey<String>('shake-modal')), findsNothing);
    expect(hapticCalls, 0);
  });
}

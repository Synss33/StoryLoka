import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/location/location_service.dart';
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

/// Lokasi tiruan — semua panggilan berjalan tanpa platform (TC-22).
class _FakeLocationService implements LocationService {
  _FakeLocationService({
    this.permission = LocationPermission.denied,
    this.serviceEnabled = true,
  });

  LocationPermission permission;
  bool serviceEnabled;
  int requestCount = 0;
  bool openedAppSettings = false;
  bool openedLocationSettings = false;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCount++;
    return permission;
  }

  @override
  Future<LatLng> getCurrentPosition() async => const LatLng(-6.2, 106.8);

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings = true;
    return true;
  }
}

/// Test case WF-06 LBS: TC-22 (izin lokasi ditolak → kartu ajakan +
/// Buka Pengaturan) beserta state GPS mati (workflow 5.10).
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf06_lbs');
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

  Future<void> pumpApp(WidgetTester tester, _FakeLocationService fake) async {
    final user = await tester.runAsync(
      () => UserRepository(db).register(
        name: 'Pengguna Uji',
        email: 'uji@example.com',
        password: 'KataSandi!123',
      ),
    );
    store = InMemoryAuthStore()
      ..session = SessionRules.create(user?.id ?? 1);
    appRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWith((ref) async => db),
          biometricServiceProvider.overrideWithValue(_NoBiometric()),
          locationServiceProvider.overrideWithValue(fake),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    appRouter.go('/explore');
    await tester.pumpAndSettle();
  }

  Future<void> openPetaSegment(WidgetTester tester) async {
    await tester.tap(find.text('Peta'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TC-22: izin lokasi ditolak → kartu ajakan + Buka Pengaturan',
      (tester) async {
    final fake = _FakeLocationService(permission: LocationPermission.denied);
    await pumpApp(tester, fake);

    await openPetaSegment(tester);

    expect(
      find.byKey(const ValueKey<String>('location-permission-card')),
      findsOneWidget,
      reason: 'izin ditolak → kartu ajakan (workflow 5.10)',
    );
    expect(find.text('Izin Lokasi Diperlukan'), findsOneWidget);
    expect(find.text('Buka Pengaturan'), findsOneWidget);

    // Buka Pengaturan → membuka halaman izin aplikasi.
    await tester.tap(find.byKey(const ValueKey<String>('open-app-settings')));
    await tester.pump();
    expect(fake.openedAppSettings, isTrue);

    // Izinkan Lokasi → memicu permintaan izin runtime; tetap ditolak
    // sehingga kartu tetap tampil.
    await tester.tap(find.byKey(const ValueKey<String>('request-location')));
    await tester.pumpAndSettle();
    expect(fake.requestCount, 1);
    expect(
      find.byKey(const ValueKey<String>('location-permission-card')),
      findsOneWidget,
    );
    expect(fake.openedAppSettings, isTrue);
  });

  testWidgets('TC-22: GPS mati → kartu Buka Pengaturan Lokasi',
      (tester) async {
    final fake = _FakeLocationService(
      permission: LocationPermission.whileInUse,
      serviceEnabled: false,
    );
    await pumpApp(tester, fake);

    await openPetaSegment(tester);

    expect(find.text('Lokasi Perangkat Nonaktif'), findsOneWidget);
    expect(find.text('Buka Pengaturan Lokasi'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey<String>('open-location-settings')));
    await tester.pump();
    expect(fake.openedLocationSettings, isTrue);
    expect(fake.openedAppSettings, isFalse);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/app/theme_mode_provider.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/sensors/sensor_streams.dart';
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

/// Test case WF-06: TC-21 — sensor cahaya → auto-theme dengan histeresis
/// ≥ 2 dtk (dokumen desain Bagian 4 / workflow 3.6).
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late StreamController<int> lux;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    lux = StreamController<int>.broadcast();
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf06_theme');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
  });

  tearDown(() async {
    PasswordHasher.iterations = PasswordHasher.defaultIterations;
    if (!lux.isClosed) await lux.close();
    try {
      await db.close();
    } catch (_) {}
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ThemeMode?> pumpApp(WidgetTester tester) async {
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
          luxStreamProvider.overrideWithValue(lux.stream),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
  }

  /// mode tema aktif pada [MaterialApp].
  ThemeMode? themeOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

  /// Memberi lux lalu menunggu masa histeresis 2 dtk.
  Future<void> feedLux(WidgetTester tester, int value) async {
    lux.add(value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  }

  testWidgets(
      'TC-21: lux < 15 ≥ 2 dtk → Dark; zona mati diabaikan; lux > 40 → Light',
      (tester) async {
    expect(await pumpApp(tester), ThemeMode.system);

    // Terang (default auto mengikuti sistem) → sensor surup 5 lux.
    lux.add(5);
    await tester.pump();
    expect(
      themeOf(tester),
      ThemeMode.system,
      reason: 'perubahan hanya setelah ≥ 2 dtk (Bagian 4)',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(themeOf(tester), ThemeMode.dark);

    // Zona mati 15…40 lux → tidak berkedip, tetap Dark.
    await feedLux(tester, 30);
    expect(themeOf(tester), ThemeMode.dark);

    // Terang kembali: 120 lux selama ≥ 2 dtk → Light.
    await feedLux(tester, 120);
    expect(themeOf(tester), ThemeMode.light);
  });

  testWidgets('TC-21: mode manual mengabaikan sensor & reset override',
      (tester) async {
    await pumpApp(tester);

    // Auto → sensor membuat Dark.
    await feedLux(tester, 5);
    expect(themeOf(tester), ThemeMode.dark);

    // Pengguna memilih mode manual Terang → override sensor dibatalkan.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorylokaApp)),
    );
    container.read(themeModeProvider.notifier).set(StorylokaThemeMode.terang);
    await tester.pump();
    expect(themeOf(tester), ThemeMode.light);

    // Sensor melaporkan gelap — mode manual tetap diabaikan.
    await feedLux(tester, 5);
    expect(themeOf(tester), ThemeMode.light);
  });
}

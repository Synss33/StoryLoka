import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';

/// Biometrik palsu: channel `local_auth` tidak pernah merespons di host,
/// maka SCR-09 memakai versi ini agar tidak menggantung (WF-04).
class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Smoke test fondasi WF-01 + WF-02: splash → Beranda (sesi valid),
/// bottom nav 5 slot, dan dialog konfirmasi Logout.
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // Hash cepat untuk test (nilai produksi dikunci di password_hasher_test).
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_widget_test');
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
    // Sesi valid disuntikkan agar splash menuju Beranda (alur WF-02);
    // tanpa sesi, splash akan berakhir di form login (`/auth`).
    // Pembuatan pengguna (hash + SQLite) dijalankan di luar zona fake-async
    // via runAsync agar tidak menunggu timer yang belum pernah dipompa.
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
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump(); // memulai timer splash
    expect(find.text('Storyloka'), findsOneWidget);
    // Lewati splash 1,5 detik menuju Beranda.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  testWidgets('splash berpindah ke Beranda dan bottom nav 5 slot tampil',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Halo, Pembaca'), findsOneWidget);
    for (final label in <String>[
      'Beranda',
      'Explore',
      'Profil',
      'Kesan',
      'Logout',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'slot "$label"');
    }
  });

  testWidgets('slot Logout membuka dialog konfirmasi, bukan layar baru',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Keluar dari Storyloka?'), findsOneWidget);
    expect(find.text('Sesi akan diakhiri.'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    // Tutup dialog lewat Batal.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari Storyloka?'), findsNothing);
    expect(find.text('Halo, Pembaca'), findsOneWidget);
  });

  testWidgets('berpindah tab Explore/Profil/Kesan menampilkan layarnya',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Jelajahi Fitur Tambahan'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Keamanan & Sesi'), findsOneWidget);

    await tester.tap(find.text('Kesan'));
    await tester.pumpAndSettle();
    expect(find.text('SIMPAN / KIRIM'), findsOneWidget);
  });

  testWidgets('layar fokus menyembunyikan bottom nav (Bagian 3.3)',
      (tester) async {
    await pumpApp(tester);

    // SCR-08 Pencarian = layar fokus: tanpa bottom nav.
    appRouter.go('/search');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian'), findsOneWidget);
    expect(find.text('Beranda'), findsNothing);
    expect(find.text('Logout'), findsNothing);
  });
}

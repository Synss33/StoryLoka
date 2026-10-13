import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/db/settings_repository.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';

/// Uji black-box WF-02 — test case TC-01 s.d. TC-08
/// (docs/workflow_proyek.md Bagian 6).
///
/// Biometrik memakai fake (perangkat fisik diuji manual); SQLCipher di host
/// diganti pabrik ffi (lihat docs/keputusan.md butir 7).
class FakeBiometricService extends BiometricService {
  FakeBiometricService({this.supported = true, this.result = true});

  bool supported;
  bool result;
  int calls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({
    String reason = 'Verifikasi identitas untuk masuk ke Storyloka',
  }) async {
    calls++;
    return result;
  }
}

void main() {
  late Directory tempDir;
  late Database db;
  late InMemoryAuthStore store;
  late FakeBiometricService biometric;

  setUp(() async {
    // Hash cepat untuk test (nilai produksi dikunci di password_hasher_test).
    PasswordHasher.iterations = 1000;
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('storyloka_auth_test');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    store = InMemoryAuthStore();
    biometric = FakeBiometricService();
  });

  tearDown(() async {
    PasswordHasher.iterations = PasswordHasher.defaultIterations;
    try {
      await db.close();
    } catch (_) {
      // Sudah ditutup provider saat logout — diabaikan.
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) async => db),
          authStoreProvider.overrideWithValue(store),
          biometricServiceProvider.overrideWithValue(biometric),
        ],
        child: const StorylokaApp(),
      );

  /// Splash → rute tujuan (timer 1,5 detik + penyelesaian async).
  Future<void> pumpSplash(WidgetTester tester) async {
    appRouter.go('/splash');
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  /// Memompa beberapa kali agar rantai async (hash, SQLite, rute) selesai.
  Future<void> settleAsync(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> fillRegister(
    WidgetTester tester, {
    String name = 'Budi Santoso',
    String email = 'budi@example.com',
    String password = 'KataSandi!123',
    String confirm = 'KataSandi!123',
  }) async {
    await tester.tap(find.byKey(const Key('tab-Daftar')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('field-register-name')),
      name,
    );
    await tester.enterText(
      find.byKey(const Key('field-register-email')),
      email,
    );
    await tester.enterText(
      find.byKey(const Key('field-register-password')),
      password,
    );
    await tester.enterText(
      find.byKey(const Key('field-register-confirm')),
      confirm,
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('auth-submit')));
    await settleAsync(tester);
  }

  testWidgets('TC-01: register valid → akun dibuat, masuk SCR-02',
      (tester) async {
    await pumpSplash(tester);
    expect(find.byKey(const Key('field-login-identifier')), findsOneWidget);

    await fillRegister(tester);
    await submit(tester);

    expect(find.text('Halo, Pembaca'), findsOneWidget);
    expect(store.session, isNotNull);
    expect(store.session!.userId, 1);
  });

  testWidgets('TC-02: password < 8 karakter ditolak dengan pesan validasi',
      (tester) async {
    await pumpSplash(tester);
    await fillRegister(tester, password: 'abc12', confirm: 'abc12');
    await submit(tester);

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    // Tetap di form, tidak masuk beranda.
    expect(find.byKey(const Key('field-register-name')), findsOneWidget);
    expect(find.text('Halo, Pembaca'), findsNothing);
  });

  testWidgets('TC-03: login password salah → pesan umum + hitung percobaan',
      (tester) async {
    // Siapkan satu pengguna terdaftar (hash + SQLite di luar zona fake-async).
    final repo = UserRepository(db);
    await tester.runAsync(
      () => repo.register(
        name: 'Budi',
        email: 'budi@example.com',
        password: 'KataSandi!123',
      ),
    );

    await pumpSplash(tester);
    expect(find.byKey(const Key('field-login-identifier')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('field-login-identifier')),
      'budi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('field-login-password')),
      'password-salah',
    );
    await submit(tester);

    expect(find.text('Email atau password salah.'), findsOneWidget);
    expect(find.text('Percobaan gagal: 1'), findsOneWidget);
    expect(store.session, isNull);
    expect(find.text('Halo, Pembaca'), findsNothing);
  });

  testWidgets('TC-04: password tersimpan ter-hash (tidak ada teks polos)',
      (tester) async {
    await pumpSplash(tester);
    await fillRegister(tester);
    await submit(tester);

    final rows = await tester.runAsync(
      () => db.query(
        'users',
        columns: ['password_hash', 'salt', 'kdf_params'],
        where: 'email = ?',
        whereArgs: ['budi@example.com'],
      ),
    );
    expect(rows, isNotNull);
    expect(rows!, hasLength(1));
    final hash = rows.first['password_hash'] as String;
    final salt = rows.first['salt'] as String;
    final kdf = rows.first['kdf_params'] as String;

    expect(hash.length, 64);
    expect(salt.length, 32);
    expect(kdf, contains('PBKDF2-HMAC-SHA256'));
    for (final secret in <String>['KataSandi!123', 'budi@example.com']) {
      expect(hash.contains(secret), isFalse);
      expect(kdf.contains(secret), isFalse);
    }
  });

  testWidgets('TC-05: sesi kedaluwarsa → dialog "Sesi berakhir" → login',
      (tester) async {
    store.session = SessionInfo(
      token: 'a' * 64,
      userId: 1,
      expiresAt:
          DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    await pumpSplash(tester);

    expect(find.text('Sesi berakhir'), findsWidgets); // judul dialog
    expect(find.text('Sesi berakhir, silakan masuk lagi.'), findsOneWidget);
    expect(store.session, isNull); // sesi basi dihapus

    await tester.tap(find.text('Oke'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('field-login-identifier')), findsOneWidget);
  });

  testWidgets('TC-06: biometrik aktif + verifikasi sukses → SCR-02',
      (tester) async {
    // Pengguna + pengaturan biometrik + sesi valid (di luar zona fake-async).
    final settings = SettingsRepository(db);
    final user = await tester.runAsync(() async {
      final repo = UserRepository(db);
      final created = await repo.register(
        name: 'Budi',
        email: 'budi@example.com',
        password: 'KataSandi!123',
      );
      await settings.setBiometricEnabled(created.id, true);
      return created;
    });
    store.session = SessionRules.create(user!.id);
    biometric.result = true;

    await pumpSplash(tester);

    expect(biometric.calls, greaterThanOrEqualTo(1));
    expect(find.text('Halo, Pembaca'), findsOneWidget);
  });

  testWidgets('TC-07: biometrik gagal 3× → form password', (tester) async {
    final settings = SettingsRepository(db);
    final user = await tester.runAsync(() async {
      final repo = UserRepository(db);
      final created = await repo.register(
        name: 'Budi',
        email: 'budi@example.com',
        password: 'KataSandi!123',
      );
      await settings.setBiometricEnabled(created.id, true);
      return created;
    });
    store.session = SessionRules.create(user!.id);
    biometric.result = false;

    await pumpSplash(tester);

    expect(biometric.calls, 3);
    expect(find.byKey(const Key('field-login-identifier')), findsOneWidget);
    expect(
      find.text('Biometrik gagal 3 kali. Gunakan password.'),
      findsOneWidget,
    );
    expect(find.text('Halo, Pembaca'), findsNothing);
  });

  testWidgets('TC-08: logout → token terhapus, kembali ke SCR-01',
      (tester) async {
    await pumpSplash(tester);
    await fillRegister(tester);
    await submit(tester);
    expect(find.text('Halo, Pembaca'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    // Kembali ke splash (SCR-01) → tanpa sesi → form login.
    expect(find.text('Storyloka'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.byKey(const Key('field-login-identifier')), findsOneWidget);
    expect(find.text('Halo, Pembaca'), findsNothing);
  });
}

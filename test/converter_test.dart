import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/network/rates_service.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/core/utils/currency.dart';
import 'package:storyloka/core/utils/world_clock.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';

class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Test case WF-05: TC-17 (konversi kurs) dan TC-18 (konversi waktu).
void main() {
  // ---- TC-17: konversi mata uang ---------------------------------------
  group('TC-17 konversi kurs', () {
    final snapshot = RateSnapshot(
      rates: const {'IDR': 1, 'USD': 16300.0, 'EUR': 17800.0, 'JPY': 108.0},
      fetchedAt: DateTime(2026, 10, 13, 9, 30).millisecondsSinceEpoch,
    );

    test('100 USD → IDR = 100 × kurs', () {
      final idr = CurrencyConverter.convert(
        amount: 100,
        from: Currency.usd,
        to: Currency.idr,
        snapshot: snapshot,
      );
      expect(idr, 100 * 16300.0);
      expect(CurrencyConverter.format(idr!), '1.630.000');
    });

    test('konversi bolak-balik konsisten & kurs tak tersedia → null', () {
      final back = CurrencyConverter.convert(
        amount: 1630000,
        from: Currency.idr,
        to: Currency.usd,
        snapshot: snapshot,
      );
      expect(back, closeTo(100, 0.001));

      final missing = CurrencyConverter.convert(
        amount: 1,
        from: Currency.eur,
        to: Currency.usd,
        snapshot: const RateSnapshot(rates: {'IDR': 1}, fetchedAt: 0),
      );
      expect(missing, isNull);
    });
  });

  // ---- TC-18: konversi zona waktu --------------------------------------
  group('TC-18 konversi waktu', () {
    test('14:00 WIB → WITA 15:00, WIT 16:00, London 08:00 (BST)', () {
      final reference = DateTime(2026, 6, 15, 14, 0); // Senin, musim panas
      final times = WorldClock.convertAll(reference);

      expect(WorldClock.formatHm(times[WorldZone.wib]!), '14:00');
      expect(WorldClock.formatHm(times[WorldZone.wita]!), '15:00');
      expect(WorldClock.formatHm(times[WorldZone.wit]!), '16:00');
      // Juni → DST aktif: 14:00 WIB = 07:00 UTC = 08:00 BST.
      expect(WorldClock.formatHm(times[WorldZone.london]!), '08:00');
    });

    test('London di luar DST (Januari) memakai GMT', () {
      final reference = DateTime(2026, 1, 15, 14, 0);
      final times = WorldClock.convertAll(reference);
      expect(WorldClock.formatHm(times[WorldZone.london]!), '07:00');
    });

    test('format tampilan panel waktu', () {
      expect(WorldClock.formatHm(DateTime(2026, 10, 13, 7, 5)), '07:05');
      expect(WorldClock.formatHm(DateTime(2026, 10, 13, 16, 0)), '16:00');
      expect(WorldClock.formatTanggal(DateTime(2026, 10, 13)), 'Sel, 13 Okt 2026');
    });
  });

  // ---- TC-17 (UI): panel kurs di SCR-04 --------------------------------
  group('TC-17 UI konverter mata uang', () {
    late InMemoryAuthStore store;
    late Database db;
    late Directory tempDir;

    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      PasswordHasher.iterations = 1000;
      tempDir = await Directory.systemTemp.createTemp('storyloka_rates');
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

    testWidgets('panel menampilkan hasil 100 USD → IDR + waktu pembaruan',
        (tester) async {
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
            ratesProvider.overrideWith(
              (ref) async => RatesResult(
                snapshot: RateSnapshot(
                  rates: const {'IDR': 1, 'USD': 16300.0},
                  fetchedAt:
                      DateTime(2026, 10, 13, 9, 30).millisecondsSinceEpoch,
                ),
                fromCache: false,
              ),
            ),
          ],
          child: const StorylokaApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      // Panel mata uang (default 100 USD → IDR).
      expect(find.byKey(const ValueKey<String>('currency-result')), findsOneWidget);
      expect(find.textContaining('1.630.000'), findsOneWidget);

      // Ada label waktu pembaruan kurs (DoD F-17).
      final updated = tester.widget<Text>(
        find.byKey(const ValueKey<String>('rates-updated-at')),
      );
      expect(updated.data, contains('Diperbarui'));
      expect(updated.data, contains('09:30'));
    });
  });
}

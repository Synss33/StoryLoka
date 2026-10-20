import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/models/book.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/game/question_bank.dart';

/// Biometrik palsu (lihat widget_test.dart): channel `local_auth` tidak
/// merespons di host.
class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Performance testing WF-10 (deskripsi Bagian 6.7): angka dicetak dengan
/// prefix `[perf]` dan dicatat di `docs/progress.md` sebagai bahan Lembar
/// Evaluasi. Batas atas sengaja longgar agar tidak flaky antar mesin;
/// angka nyata ditulis ke laporan dari keluaran test ini.
///
/// Yang DIUKUR DI HOST: muat 200 buku (SQLCipher), build ronde kuis,
/// hash PBKDF2 produksi, dan bootstrap splash → Beranda (fake clock).
/// Yang DIUKUR DI HP: waktu start nyata, respons AI (butuh jaringan),
/// pemakaian memori (DevTools) — dicatat manual saat demo.
void main() {
  setUpAll(sqfliteFfiInit);

  group('[perf] PBKDF2 produksi (210.000 iterasi)', () {
    setUp(() {
      PasswordHasher.iterations = PasswordHasher.defaultIterations;
    });

    tearDown(() {
      PasswordHasher.iterations = PasswordHasher.defaultIterations;
    });

    test('hash + verify satu akun (bahan: waktu login terasa)', () async {
      const password = 'KataSandi!123';
      final salt = PasswordHasher.newSaltHex();

      final sw = Stopwatch()..start();
      final hash = await PasswordHasher.hash(password, salt);
      final ok = await PasswordHasher.verify(
        password: password,
        saltHex: salt,
        expectedHashHex: hash,
      );
      sw.stop();

      // ignore: avoid_print
      print('[perf] PBKDF2 hash+verify 210k iterasi: '
          '${sw.elapsedMilliseconds} ms');
      expect(ok, isTrue);
      expect(hash, hasLength(64));
      expect(
        sw.elapsedMilliseconds,
        lessThan(25000),
        reason: 'hash PBKDF2 produksi wajar < 25 dtk di host',
      );
    });
  });

  group('[perf] muat 200 buku (SQLCipher lokal)', () {
    late Directory tempDir;
    late Database db;
    late BookRepository repo;

    const userId = 1;
    const genres = <String>['Fiksi', 'Non-Fiksi', 'Sejarah', 'Sains', 'Anak'];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storyloka_perf');
      db = await openStorylokaDatabase(
        path: '${tempDir.path}/t.db',
        password: '0' * 64,
        factory: databaseFactoryFfiNoIsolate,
      );
      await db.insert('users', <String, Object?>{
        'name': 'Tester',
        'email': 'tester@example.com',
        'password_hash': 'x',
        'salt': 'y',
        'kdf_params': '{}',
        'created_at': 0,
        'updated_at': 0,
      });
      repo = BookRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Book buku(int i) => Book(
          userId: userId,
          title: 'Buku Nomor $i',
          author: 'Penulis ${i % 40}',
          genre: genres[i % genres.length],
          status: 'reading',
          rating: (i % 5) + 1.0,
          updatedAt: 0,
          dirty: false,
        );

    /// Seed 200 baris dalam SATU transaksi (setup test, bukan metrik app).
    Future<void> seed200() async {
      await db.transaction((txn) async {
        for (var i = 0; i < 200; i++) {
          final row = buku(i).toRow();
          row['updated_at'] = DateTime.now().millisecondsSinceEpoch;
          row['dirty'] = 0;
          await txn.insert('books', row);
        }
      });
    }

    test('tambah 1 buku (aksi TC-12) lalu list() memuat 200 baris', () async {
      await seed200();

      // Aksi nyata app = menambah SATU buku per kali (TC-12).
      final swInsert = Stopwatch()..start();
      final id = await repo.insert(buku(999));
      swInsert.stop();

      final swList = Stopwatch()..start();
      final loaded = await repo.list(userId, orderBy: 'title ASC');
      swList.stop();

      // ignore: avoid_print
      print('[perf] insert 1 buku: ${swInsert.elapsedMilliseconds} ms');
      // ignore: avoid_print
      print('[perf] query list() 200 buku: ${swList.elapsedMilliseconds} ms');

      expect(id, greaterThan(0));
      expect(loaded, hasLength(201));
      expect(
        swInsert.elapsedMilliseconds,
        lessThan(3000),
        reason: 'tambah 1 buku wajar < 3 dtk di host (SQLCipher + fsync)',
      );
      expect(
        swList.elapsedMilliseconds,
        lessThan(2000),
        reason: 'query koleksi wajar < 2 dtk di host',
      );
    });

    test('filter genre pada 200 buku tetap cepat', () async {
      await seed200();
      final sw = Stopwatch()..start();
      final filtered = await repo.list(userId, genre: 'Fiksi');
      sw.stop();
      // ignore: avoid_print
      print('[perf] filter genre (200 buku): ${sw.elapsedMilliseconds} ms');
      expect(filtered, isNotEmpty);
      expect(
        sw.elapsedMilliseconds,
        lessThan(2000),
        reason: 'filter wajar < 2 dtk di host',
      );
    });

    test('buildRound 10 soal dari koleksi 200 buku', () async {
      final books = [for (var i = 0; i < 200; i++) buku(i)];
      final sw = Stopwatch()..start();
      final round = QuestionBank.buildRound(books: books, random: Random(42));
      sw.stop();
      // ignore: avoid_print
      print('[perf] buildRound (bank lokal + koleksi 200 buku): '
          '${sw.elapsedMilliseconds} ms');
      expect(round, hasLength(QuestionBank.roundSize));
      expect(
        sw.elapsedMilliseconds,
        lessThan(1000),
        reason: 'generate ronde wajar < 1 dtk di host',
      );
    });
  });

  group('[perf] bootstrap aplikasi (host, fake clock)', () {
    late Directory tempDir;
    late Database db;

    setUp(() async {
      PasswordHasher.iterations = 1000;
      tempDir = await Directory.systemTemp.createTemp('storyloka_perf_boot');
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

    testWidgets('splash → Beranda: total biaya build host', (tester) async {
      final sw = Stopwatch()..start();
      final user = await tester.runAsync(
        () => UserRepository(db).register(
          name: 'Pengguna Uji',
          email: 'uji@example.com',
          password: 'KataSandi!123',
        ),
      );
      final store = InMemoryAuthStore()
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
      await tester.pump();
      expect(find.text('Storyloka'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();
      expect(find.text('Halo, Pengguna'), findsOneWidget);
      sw.stop();
      // ignore: avoid_print
      print('[perf] splash → Beranda (waktu nyata host, clock dipompa): '
          '${sw.elapsedMilliseconds} ms');
      expect(
        sw.elapsedMilliseconds,
        lessThan(10000),
        reason: 'bootstrap wajar < 10 dtk di host',
      );
    });
  });
}

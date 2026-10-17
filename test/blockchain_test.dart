import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/blockchain/hash_chain.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/models/block.dart';
import 'package:storyloka/core/models/book.dart';
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

/// Test case WF-08 Blockchain: TC-26 (blok baru saat buku selesai +
/// validasi Valid), TC-27 (tamper → Tidak Valid menunjuk blok).
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late int userId;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf08');
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
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  /// Menanam satu buku berstatus `reading` (di luar zona fake-async).
  Future<int> seedBook(WidgetTester tester, String title) async {
    final id = await tester.runAsync(
      () => BookRepository(db).insert(
        Book(
          userId: userId,
          title: title,
          author: 'Penulis Uji',
          genre: 'Fiksi',
          year: 2020,
          pages: 300,
          status: 'reading',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    return id ?? 0;
  }

  /// Alur "Ubah Status → Selesai" di SCR-06: konfirmasi + ulasan wajib.
  Future<void> completeBook(
    WidgetTester tester, {
    required String review,
  }) async {
    await tester.tap(find.byKey(const ValueKey<String>('detail-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Dialog konfirmasi "Tandai selesai?".
    expect(find.text('Tandai selesai?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('confirm-complete')));
    await tester.pumpAndSettle();

    // Dialog wajib ulasan & rating (judul kartu SCR-06 sama → cari via
    // field ulasan di dalam dialog).
    final reviewField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byKey(const ValueKey<String>('review-field')),
    );
    expect(reviewField, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('star-5')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(reviewField, review);
    await tester.tap(find.byKey(const ValueKey<String>('save-review')));
    // Tunggu dialog tertutup (zona fake-async — pump loop).
    for (var i = 0; i < 30 && reviewField.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(reviewField, findsNothing);
  }

  // ---------------------------------------------------------------------------
  // Unit test murni HashChain (hash deterministik + aturan rantai).
  // ---------------------------------------------------------------------------
  group('HashChain', () {
    test('sha256Hex deterministik 64 karakter heksadesimal', () {
      // SHA-256("abc") — vektor standar SHA.
      expect(
        HashChain.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(HashChain.sha256Hex('abc'), HashChain.sha256Hex('abc'));
      expect(HashChain.sha256Hex('abc').length, 64);
    });

    test('buildBlock: review_hash = SHA256(ulasan); genesis = 64 nol', () {
      final block = HashChain.buildBlock(
        idx: 0,
        userId: 1,
        bookId: 10,
        reviewText: 'Buku bagus sekali.',
        finishedDate: 1760000000000,
        previousHash: HashChain.genesisPreviousHash,
        timestamp: 1760000000000,
      );
      expect(block.previousHash, '0' * 64);
      expect(block.reviewHash, HashChain.sha256Hex('Buku bagus sekali.'));
      expect(block.hash, HashChain.blockHash(block));
      expect(block.hash.length, 64);
    });

    test('validate: rantai dua blok valid; tamper menunjuk blok rusak', () {
      final b0 = HashChain.buildBlock(
        idx: 0,
        userId: 1,
        bookId: 10,
        reviewText: 'Ulasan pertama',
        finishedDate: 1760000000000,
        previousHash: HashChain.genesisPreviousHash,
        timestamp: 1760000000000,
      );
      final b1 = HashChain.buildBlock(
        idx: 1,
        userId: 1,
        bookId: 11,
        reviewText: 'Ulasan kedua',
        finishedDate: 1760003600000,
        previousHash: b0.hash,
        timestamp: 1760003600000,
      );
      expect(HashChain.validate(const []).valid, isTrue);
      expect(HashChain.validate([b0]).valid, isTrue);
      expect(HashChain.validate([b0, b1]).valid, isTrue);

      // Tamper isi blok ke-1 → hash tersimpan tidak cocok.
      final tampered = Block(
        idx: b1.idx,
        userId: b1.userId,
        timestamp: b1.timestamp,
        bookId: b1.bookId,
        reviewHash: b1.reviewHash,
        finishedDate: b1.finishedDate + 1,
        previousHash: b1.previousHash,
        hash: b1.hash,
      );
      final result = HashChain.validate([b0, tampered]);
      expect(result.valid, isFalse);
      expect(result.brokenIndex, 1);
    });

    test('validate: previous_hash putus menunjuk blok penyambung', () {
      final b0 = HashChain.buildBlock(
        idx: 0,
        userId: 1,
        bookId: 10,
        reviewText: 'A',
        finishedDate: 1,
        previousHash: HashChain.genesisPreviousHash,
        timestamp: 1,
      );
      // Blok kedua salah menunjuk (bukan hash b0) → rusak di idx 1.
      final broken = Block(
        idx: 1,
        userId: 1,
        timestamp: 2,
        bookId: 11,
        reviewHash: HashChain.sha256Hex('B'),
        finishedDate: 2,
        previousHash: 'f' * 64,
        hash: 'e' * 64,
      );
      final result = HashChain.validate([b0, broken]);
      expect(result.valid, isFalse);
      expect(result.brokenIndex, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // TC-26 / TC-27 — alur penuh lewat SCR-06.
  // ---------------------------------------------------------------------------
  testWidgets('TC-26: tandai selesai → blok dibuat + notifikasi + Valid',
      (tester) async {
    await pumpApp(tester);
    final bookId = await seedBook(tester, 'Laskar Pelangi');

    appRouter.go('/book/$bookId');
    await tester.pumpAndSettle();

    await completeBook(
      tester,
      review: 'Mengharukan dan penuh makna.',
    );

    // Blok tersimpan di tabel blocks (genesis: idx 0, previous = 64 nol).
    final blocks = await tester.runAsync(
      () => db.query('blocks', orderBy: 'idx ASC'),
    );
    expect(blocks, hasLength(1));
    final row = blocks!.first;
    expect(row['idx'], 0);
    expect(row['book_id'], bookId);
    expect(row['previous_hash'], '0' * 64);
    expect(
      row['review_hash'],
      HashChain.sha256Hex('Mengharukan dan penuh makna.'),
    );

    // Notifikasi "Sertifikat Diterbitkan" tercatat (workflow §3.4).
    final notifications = await tester.runAsync(
      () => db.query(
        'notifications',
        where: "type = 'certificate' AND user_id = ?",
        whereArgs: [userId],
      ),
    );
    expect(notifications, hasLength(1));
    expect(notifications!.first['title'], 'Sertifikat Diterbitkan');
    expect(notifications.first['ref'], '/book/$bookId');

    // Kartu blockchain tampil di SCR-06 → Validasi Rantai → Valid.
    final card = find.byKey(const ValueKey<String>('blockchain-card'));
    await tester.scrollUntilVisible(card, 240);
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    expect(find.textContaining('Blok #0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('validate-chain')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('chain-valid')), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
  });

  testWidgets('TC-27: ubah data blok manual → Tidak Valid (blok ke-0)',
      (tester) async {
    await pumpApp(tester);
    final bookId = await seedBook(tester, 'Buku Tamper');

    appRouter.go('/book/$bookId');
    await tester.pumpAndSettle();
    await completeBook(tester, review: 'Ulasan sebelum ditamper.');

    // Tamper: ubah `finished_date` blok secara manual (di luar zona
    // fake-async) tanpa menghitung ulang hash → rantai rusak.
    await tester.runAsync(
      () => db.update(
        'blocks',
        {'finished_date': 1760099999999},
        where: 'user_id = ? AND idx = 0',
        whereArgs: [userId],
      ),
    );

    final card = find.byKey(const ValueKey<String>('blockchain-card'));
    await tester.scrollUntilVisible(card, 240);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('validate-chain')));
    await tester.pumpAndSettle();

    // Hasil: Tidak Valid yang menunjuk nomor blok bermasalah.
    expect(
      find.byKey(const ValueKey<String>('chain-invalid')),
      findsOneWidget,
    );
    expect(find.text('Tidak Valid (blok ke-0)'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('chain-valid')), findsNothing);
  });

  testWidgets('Bagikan Sertifikat → pratinjau sertifikat tampil',
      (tester) async {
    await pumpApp(tester);
    final bookId = await seedBook(tester, 'Buku Sertifikat');

    appRouter.go('/book/$bookId');
    await tester.pumpAndSettle();
    await completeBook(tester, review: 'Sertifikat wajib ada.');

    final card = find.byKey(const ValueKey<String>('blockchain-card'));
    await tester.scrollUntilVisible(card, 240);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('share-certificate')));
    await tester.pumpAndSettle();

    // Dialog pratinjau berisi sertifikat + tombol "Bagikan Gambar".
    expect(find.text('Sertifikat Bacaan'), findsOneWidget);
    expect(find.text('SERTIFIKAT BACAAN'), findsOneWidget);
    expect(find.text('Buku Sertifikat'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('certificate-share')),
      findsOneWidget,
    );

    // Tutup tanpa membagikan (hindari panggilan platform share di host).
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('SERTIFIKAT BACAAN'), findsNothing);
  });
}

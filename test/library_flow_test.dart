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
import 'package:storyloka/core/network/book_search_service.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/reading_session/session_timer.dart';

/// Biometrik palsu agar layar tidak menggantung (lihat widget_test.dart).
class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Hasil pencarian online tiruan — tanpa jaringan (TC-13).
class _FakeSearch implements BookSearchService {
  @override
  Future<List<OnlineBookResult>> search(String query) async =>
      const <OnlineBookResult>[
        OnlineBookResult(
          title: 'Sang Pemimpi',
          author: 'Andrea Hirata',
          publisher: 'Bentang Pustaka',
          year: 2018,
          pages: 360,
          genre: 'Fiksi',
          source: 'Google Books',
        ),
      ];
}

/// Test case WF-05: TC-12 (tambah buku), TC-13 (pilih hasil online),
/// TC-14 (filter), TC-15 (stopwatch timestamp), TC-16 (sesi → selesai
/// dengan ulasan wajib).
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
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf05');
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
          bookSearchServiceProvider.overrideWithValue(_FakeSearch()),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  /// Menyiapkan satu buku langsung di SQLite (di luar zona fake-async).
  Future<int> seedBook(
    WidgetTester tester, {
    required String title,
    String genre = 'Fiksi',
    int? year = 2020,
    double? rating = 5,
    int pages = 300,
    String status = 'completed',
  }) async {
    final id = await tester.runAsync(
      () => BookRepository(db).insert(
        Book(
          userId: userId,
          title: title,
          author: 'Penulis Uji',
          genre: genre,
          year: year,
          rating: rating,
          pages: pages,
          status: status,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    return id ?? 0;
  }

  /// Pompa frame terbatas — layar sesi punya stopwatch periodik sehingga
  /// `pumpAndSettle` tidak akan pernah selesai.
  Future<void> pumpFrames(
    WidgetTester tester, {
    int frames = 20,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(step);
    }
  }

  testWidgets('TC-12: tambah buku → Simpan → muncul di Koleksi',
      (tester) async {
    await pumpApp(tester);

    appRouter.go('/library');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('add-book-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Buku'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('field-title')),
      'Laskar Pelangi',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('field-author')),
      'Andrea Hirata',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('field-pages')),
      '520',
    );
    // Tombol simpan berada di bawah form panjang — gulir dulu.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('save-book')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('save-book')));
    await tester.pumpAndSettle();

    // Kembali ke Library dan buku baru tampil di koleksi.
    expect(find.text('Laskar Pelangi'), findsOneWidget);

    final rows = await tester.runAsync(
      () => db.query('books', where: 'title = ?', whereArgs: ['Laskar Pelangi']),
    );
    expect(rows, hasLength(1));
    expect(rows!.first['pages'], 520);
    expect(rows.first['user_id'], userId);
  });

  testWidgets('TC-13: pilih hasil pencarian online → form terisi otomatis',
      (tester) async {
    await pumpApp(tester);

    appRouter.go('/search');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('search-field')),
      'sang pemimpi',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cari Online'));
    await tester.pumpAndSettle();

    expect(find.text('Sang Pemimpi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pick-Sang Pemimpi')));
    await tester.pumpAndSettle();

    // Form SCR-07 terisi otomatis dari hasil online.
    expect(find.text('Tambah Buku'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Sang Pemimpi'),
      findsOneWidget,
      reason: 'judul terisi otomatis',
    );
    expect(
      find.widgetWithText(TextFormField, 'Andrea Hirata'),
      findsOneWidget,
      reason: 'penulis terisi otomatis',
    );
    expect(
      find.widgetWithText(TextFormField, '360'),
      findsOneWidget,
      reason: 'jumlah halaman terisi otomatis',
    );
  });

  testWidgets('TC-14: filter genre + rating ≥ 4 + tahun → hanya hasil sesuai',
      (tester) async {
    await pumpApp(tester);

    await seedBook(tester, title: 'Buku Sesuai', genre: 'Fiksi', year: 2020, rating: 5);
    await seedBook(tester, title: 'Buku Rating Rendah', genre: 'Fiksi', year: 2020, rating: 3);
    await seedBook(tester, title: 'Buku Tahun Lama', genre: 'Fiksi', year: 2018, rating: 5);
    await seedBook(tester, title: 'Buku Genre Lain', genre: 'Sains', year: 2020, rating: 5);

    appRouter.go('/library');
    await tester.pumpAndSettle();

    // Sebagian buku tampil sebelum difilter (urutan Terbaru).
    expect(find.text('Buku Genre Lain'), findsOneWidget);
    expect(find.text('Buku Tahun Lama'), findsOneWidget);

    await tester.ensureVisible(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();

    // Genre + rating minimal + tahun terbit (Bagian 6 SCR-08).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Fiksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '4+'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '2020'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('apply-filter')));
    await tester.pumpAndSettle();

    expect(find.text('Buku Sesuai'), findsOneWidget);
    expect(find.text('Buku Rating Rendah'), findsNothing);
    expect(find.text('Buku Tahun Lama'), findsNothing);
    expect(find.text('Buku Genre Lain'), findsNothing);
  });

  test('TC-15: stopwatch dihitung dari timestamp — akurat di latar belakang',
      () {
    final t0 = 1760000000000; // epoch ms sembarang
    final timer = SessionTimer(startTs: t0);

    // 2 menit berlalu (aplikasi sempat ke latar belakang) → akurat ±1 dtk.
    expect(timer.durationSec(t0 + 120000), 120);
    expect(timer.durationSec(t0 + 121999), 121);

    // Jeda 30 detik (130s → 160s) tidak ikut dihitung.
    timer.pause(t0 + 130000);
    expect(timer.isPaused, isTrue);
    expect(timer.durationSec(t0 + 160000), 130); // selama jeda: tetap 130
    timer.resume(t0 + 160000);
    expect(timer.durationSec(t0 + 200000), 170); // 200s − 30s jeda

    // Format tampilan stopwatch SCR-15.
    expect(SessionTimer.format(121000), '00:02:01');
  });

  testWidgets(
      'TC-16: halaman = total → dialog selesai → ulasan & rating wajib',
      (tester) async {
    await pumpApp(tester);
    final bookId = await seedBook(
      tester,
      title: 'Buku Rampung',
      pages: 3,
      rating: null,
      status: 'reading',
    );
    expect(bookId, greaterThan(0));

    // `push` agar setelah sesi tersimpan layar dapat kembali (pop).
    appRouter.push('/session?id=$bookId');
    await tester.pump();
    await pumpFrames(tester);
    expect(find.text('Halaman terakhir'), findsOneWidget);

    // Naikkan halaman terakhir sampai tembus total halaman (3).
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey<String>('page-plus')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const ValueKey<String>('page-value')),
      findsOneWidget,
    );

    // Tombol simpan berada di bawah — gulir dulu agar terlihat.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('save-session')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey<String>('save-session')));

    // Dialog konfirmasi "Tandai selesai?".
    for (var i = 0; i < 30 && find.text('Tandai selesai?').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Tandai selesai?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('confirm-complete')));

    // Dialog wajib ulasan & rating.
    for (var i = 0; i < 30 && find.text('Ulasan & Rating').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Ulasan & Rating'), findsOneWidget);

    // Tanpa rating → ditolak.
    await tester.tap(find.byKey(const ValueKey<String>('save-review')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pilih rating bintang 1–5.'), findsOneWidget);

    // Rating ada tapi ulasan kosong → ditolak.
    await tester.tap(find.byKey(const ValueKey<String>('star-4')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey<String>('save-review')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Ulasan wajib diisi.'), findsOneWidget);

    // Lengkapi ulasan → tersimpan, sesi ditutup.
    await tester.enterText(
      find.byKey(const ValueKey<String>('review-field')),
      'Singkat, padat, dan menginspirasi.',
    );
    await tester.tap(find.byKey(const ValueKey<String>('save-review')));
    for (var i = 0; i < 30 && find.text('Ulasan & Rating').evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Ulasan & Rating'), findsNothing);

    // Sesi tersimpan: durasi tercatat + status buku menjadi completed.
    final sessions = await tester.runAsync(
      () => db.query('reading_sessions', where: 'book_id = ?', whereArgs: [bookId]),
    );
    expect(sessions, hasLength(1));
    expect(sessions!.first['duration_sec'], isNotNull);

    final books = await tester.runAsync(
      () => db.query('books', where: 'id = ?', whereArgs: [bookId]),
    );
    expect(books!.first['status'], 'completed');
    expect(books.first['rating'], 4);

    final reviews = await tester.runAsync(
      () => db.query('reviews', where: 'book_id = ?', whereArgs: [bookId]),
    );
    expect(reviews, hasLength(1));
    expect(reviews!.first['rating'], 4);
  });
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/db/game_score_repository.dart';
import 'package:storyloka/core/models/book.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/core/theme/app_theme.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/game/game_screen.dart';
import 'package:storyloka/features/game/question_bank.dart';
import 'package:storyloka/features/game/quiz_session.dart';

/// Biometrik palsu agar layar tidak menggantung (lihat widget_test.dart).
class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Menyetel `userId` pada authController sebelum layar game membacanya.
class _AdoptSession extends StatefulWidget {
  const _AdoptSession({required this.userId, required this.child});

  final int userId;
  final Widget child;

  @override
  State<_AdoptSession> createState() => _AdoptSessionState();
}

class _AdoptSessionState extends State<_AdoptSession> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProviderScope.containerOf(context, listen: false)
          .read(authControllerProvider.notifier)
          .adoptSession(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Test case WF-09 Mini Game: TC-28 (selesaikan 10 soal → skor & koin
/// tersimpan di `game_scores`) + unit QuizSession & QuestionBank.
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
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf09');
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

  List<TriviaQuestion> fixedRound({int correctIndex = 0}) =>
      List<TriviaQuestion>.generate(
        10,
        (i) => TriviaQuestion(
          prompt: 'Soal uji $i',
          options: const ['A', 'B', 'C', 'D'],
          correctIndex: correctIndex,
          category: 'penulis',
        ),
      );

  List<Override> overrides() => <Override>[
        authStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWith((ref) async => db),
        biometricServiceProvider.overrideWithValue(_NoBiometric()),
      ];

  Future<void> pumpApp(WidgetTester tester) async {
    final user = await tester.runAsync(
      () => UserRepository(db).register(
        name: 'Pengguna Uji',
        email: 'uji@example.com',
        password: 'KataSandi!123',
      ),
    );
    userId = user?.id ?? 1;
    store = InMemoryAuthStore()..session = SessionRules.create(userId);
    appRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  /// Pompa layar SCR-16 secara langsung (soal deterministik).
  Future<void> pumpGame(
    WidgetTester tester, {
    List<TriviaQuestion>? questions,
    int questionSeconds = 30,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: _AdoptSession(
            userId: userId,
            child: GameScreen(
              questionSeconds: questionSeconds,
              questionsOverride: questions,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // adoptSession berjalan post-frame → pump sekali lagi agar intro tampil.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Menjawab semua soal dengan opsi [optionIndex]; timer periodik →
  /// pompa terbatas (bukan pumpAndSettle).
  Future<void> answerAll(
    WidgetTester tester, {
    int optionIndex = 0,
  }) async {
    for (var q = 0; q < 10; q++) {
      final tile = find.byKey(ValueKey<String>('answer-$optionIndex'));
      for (var i = 0; i < 40 && tile.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tile, findsOneWidget, reason: 'soal ke-${q + 1} harus tampil');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 1100));
    }
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byKey(const ValueKey<String>('play-again')).evaluate().isNotEmpty) {
        break;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Unit: QuestionBank & QuizSession
  // -------------------------------------------------------------------------

  group('QuestionBank', () {
    test('ronde selalu berisi 10 soal tanpa koleksi', () {
      final round = QuestionBank.buildRound(
        books: const <Book>[],
        random: Random(42),
      );
      expect(round.length, QuestionBank.roundSize);
      for (final q in round) {
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('posisi opsi diacak — jawaban benar tidak selalu pilihan A', () {
      // Seluruh soal bank lokal didefinisikan correctIndex:0; buildRound
      // wajib mengacak opsi agar pemain tidak menebak A terus (perbaikan).
      for (final seed in <int>[1, 7, 42, 99]) {
        final round = QuestionBank.buildRound(
          books: const <Book>[],
          random: Random(seed),
        );
        for (final q in round) {
          final original = QuestionBank.local.firstWhere(
            (o) => o.prompt == q.prompt,
            orElse: () => q,
          );
          // Teks jawaban benar identik dengan bank; hanya urutan berubah.
          expect(q.options[q.correctIndex],
              original.options[original.correctIndex]);
          expect(q.options.toSet(), original.options.toSet());
        }
      }

      final round = QuestionBank.buildRound(
        books: const <Book>[],
        random: Random(42),
      );
      final nonZero =
          round.where((q) => q.correctIndex != 0).length;
      expect(nonZero, greaterThan(0),
          reason: 'minimal ada soal dengan jawaban benar bukan di A');
    });

    test('soal koleksi dibuat bila ada ≥ 2 buku berpenulis berbeda', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final books = <Book>[
        Book(
          userId: 1,
          title: 'Laskar Pelangi',
          author: 'Andrea Hirata',
          updatedAt: now,
        ),
        Book(
          userId: 1,
          title: 'Bumi Manusia',
          author: 'Pramoedya',
          updatedAt: now,
        ),
        Book(
          userId: 1,
          title: 'Sang Pemimpi',
          author: 'Andrea Hirata',
          updatedAt: now,
        ),
      ];
      final derived = QuestionBank.collectionQuestions(books, Random(1));
      expect(derived, isNotEmpty);
      expect(derived.first.prompt, contains('koleksimu'));
    });
  });

  group('QuizSession', () {
    test('TC-28 logika: 10 benar → skor 1000 & koin 100', () {
      final session = QuizSession(questions: fixedRound());
      for (var i = 0; i < 10; i++) {
        expect(session.isFinished, isFalse);
        expect(session.answer(0), isTrue);
        if (i < 9) {
          expect(session.next(), isTrue);
        } else {
          expect(session.next(), isFalse);
        }
      }
      expect(session.isFinished, isTrue);
      expect(session.correctCount, 10);
      expect(session.score, 1000);
      expect(session.coins, 100);
    });

    test('jawaban salah tidak menambah skor; timeout = salah', () {
      final session = QuizSession(questions: fixedRound());
      expect(session.answer(1), isTrue); // salah (correct = 0)
      expect(session.feedback, AnswerFeedback.wrong);
      expect(session.score, 0);
      expect(session.next(), isTrue);
      expect(session.timeout(), isTrue);
      expect(session.feedback, AnswerFeedback.timeout);
      expect(session.answer(0), isFalse); // sudah dijawab
    });
  });

  // -------------------------------------------------------------------------
  // Widget: TC-28
  // -------------------------------------------------------------------------

  testWidgets(
      'TC-28: selesaikan 10 soal benar → skor 1000 & koin 100 di game_scores',
      (tester) async {
    await pumpApp(tester);
    await pumpGame(tester, questions: fixedRound());

    expect(find.text('Soal 1/10'), findsNothing); // masih intro
    expect(find.byKey(const ValueKey<String>('start-quiz')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('start-quiz')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Soal 1/10'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('quiz-timer')), findsOneWidget);

    await answerAll(tester, optionIndex: 0);

    expect(find.text('Hasil Kuis'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('result-correct')), findsOneWidget);
    expect(find.text('10/10'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('play-again')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('back-home')), findsOneWidget);

    // Skor & koin tersimpan di `game_scores` (TC-28).
    final rows = await tester.runAsync(
      () => db.query(
        'game_scores',
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      ),
    );
    expect(rows, hasLength(1));
    expect(rows!.first['score'], 1000);
    expect(rows.first['coins'], 100);
  });

  testWidgets('TC-28: Main Lagi memulai ronde baru; skor bertambah',
      (tester) async {
    await pumpApp(tester);
    await pumpGame(tester, questions: fixedRound());

    await tester.tap(find.byKey(const ValueKey<String>('start-quiz')));
    await tester.pump();
    await answerAll(tester, optionIndex: 0);
    expect(find.text('Hasil Kuis'), findsOneWidget);

    // Main Lagi → soal 1 lagi, mainkan sampai selesai.
    await tester.tap(find.byKey(const ValueKey<String>('play-again')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Soal 1/10'), findsOneWidget);
    await answerAll(tester, optionIndex: 0);
    expect(find.text('Hasil Kuis'), findsOneWidget);

    // Dua baris skor (dua ronde).
    final rows = await tester.runAsync(
      () => db.query(
        'game_scores',
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
      ),
    );
    expect(rows, hasLength(2));
  });

  testWidgets('timer habis → timeout dihitung salah dan lanjut',
      (tester) async {
    await pumpApp(tester);
    // 0 detik → ticker langsung menghitung habis (timestamp nyata di
    // fake-async tidak maju, jadi durasi disuntik 0).
    await pumpGame(
      tester,
      questions: fixedRound(),
      questionSeconds: 0,
    );

    await tester.tap(find.byKey(const ValueKey<String>('start-quiz')));
    await tester.pump();

    // Tiap soal: tick 200 ms → timeout + koreksi 900 ms → soal berikut.
    // Jalankan sampai ronde selesai agar tidak ada timer tersisa.
    var sawSecond = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.text('Soal 2/10').evaluate().isNotEmpty) sawSecond = true;
      if (find.byKey(const ValueKey<String>('play-again')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(sawSecond, isTrue, reason: 'timeout harus lanjut ke soal 2');
    expect(find.text('Hasil Kuis'), findsOneWidget);
    // Pastikan Future.delayed koreksi terakhir sudah selesai.
    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets('segmen Game SCR-04 menampilkan rekor & koin', (tester) async {
    await pumpApp(tester);
    await tester.runAsync(
      () => GameScoreRepository(db).save(
        userId: userId,
        score: 500,
        coins: 50,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    appRouter.go('/explore');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Game'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('game-best-score')),
      findsOneWidget,
    );
    expect(find.text('Rekor 500'), findsOneWidget);
    expect(find.text('50 koin'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('play-trivia')), findsOneWidget);
  });

  testWidgets('koleksi pengguna menambah soal dari buku', (tester) async {
    await pumpApp(tester);
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.runAsync(() async {
      final repo = BookRepository(db);
      await repo.insert(Book(
        userId: userId,
        title: 'Laskar Pelangi',
        author: 'Andrea Hirata',
        status: 'completed',
        updatedAt: now,
      ));
      await repo.insert(Book(
        userId: userId,
        title: 'Bumi Manusia',
        author: 'Pramoedya',
        status: 'reading',
        updatedAt: now,
      ));
    });

    final books =
        await tester.runAsync(() => BookRepository(db).list(userId));
    expect(books, hasLength(2));

    final derived = QuestionBank.collectionQuestions(books!, Random(7));
    expect(derived.length, 2);
    expect(
      derived.map((q) => q.prompt).where((s) => s.contains('Laskar')),
      isNotEmpty,
    );
  });

  testWidgets('statistik koin profil membaca SUM(game_scores)',
      (tester) async {
    await pumpApp(tester);
    await tester.runAsync(() async {
      final repo = GameScoreRepository(db);
      await repo.save(
        userId: userId,
        score: 300,
        coins: 30,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await repo.save(
        userId: userId,
        score: 700,
        coins: 70,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
    final total = await tester.runAsync(
      () => GameScoreRepository(db).totalCoins(userId),
    );
    expect(total, 100);
    final best = await tester.runAsync(
      () => GameScoreRepository(db).bestScore(userId),
    );
    expect(best, 700);
  });
}

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
import 'package:storyloka/core/network/api_client.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';

class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Klien API tiruan untuk WF-07: health dan balasan `/ai/*` bisa diatur
/// per skenario (online sukses / offline).
class _FakeApi extends ApiClient {
  _FakeApi({this.healthOk = true, this.offlinePost = false})
      : super(baseUrl: 'http://localhost');

  final bool healthOk;
  final bool offlinePost;
  final List<String> postPaths = <String>[];

  @override
  Future<HealthStatus> getHealth() async => HealthStatus(
        ok: healthOk,
        message: healthOk ? 'OK' : 'tidak terjangkau',
      );

  @override
  Future<ApiResponse> postJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    postPaths.add(path);
    if (offlinePost) return const ApiResponse(status: -1);
    if (path == '/ai/summarize') {
      return ApiResponse(
        status: 200,
        body: <String, dynamic>{
          'summary':
              'Laskar Pelangi berkisah tentang perjuangan sekolah di Belitung.',
        },
      );
    }
    if (path == '/ai/chat') {
      return ApiResponse(
        status: 200,
        body: <String, dynamic>{'reply': 'Jawaban AI uji.'},
      );
    }
    if (path == '/ai/recommend') {
      return ApiResponse(
        status: 200,
        body: <String, dynamic>{
          'recommendations': 'Rekomendasi uji: Ayat-Ayat Cinta.',
        },
      );
    }
    return ApiResponse(
      status: 404,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'NOT_FOUND', 'message': 'Tidak ada'},
      },
    );
  }
}

/// Test case WF-07 AI: TC-24 (Ringkas dengan AI - ringkasan + label) dan
/// TC-25 (offline - input dinonaktifkan; gagal kirim - pesan + Coba Lagi).
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late _FakeApi api;
  late int userId;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_wf07');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    api = _FakeApi();
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
          apiClientProvider.overrideWithValue(api),
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

  /// Menanam satu buku (di luar zona fake-async) dan mengembalikan id-nya.
  Future<int> seedBook(WidgetTester tester, String title) async {
    final id = await tester.runAsync(
      () => BookRepository(db).insert(
        Book(
          userId: userId,
          title: title,
          author: 'Penulis Uji',
          genre: 'Fiksi',
          year: 2020,
          rating: 4,
          pages: 300,
          status: 'reading',
          synopsis: 'Sinopsis uji WF-07.',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
    return id ?? 0;
  }

  testWidgets('TC-24: Ringkas dengan AI → ringkasan + label', (tester) async {
    await pumpApp(tester);
    final bookId = await seedBook(tester, 'Laskar Pelangi');

    appRouter.go('/book/$bookId');
    await tester.pumpAndSettle();

    // Kartu AI berada di bawah lipatan SCR-06 (ListView lazy) — gulir dulu.
    final aiSummarize = find.byKey(const ValueKey<String>('ai-summarize'));
    await tester.scrollUntilVisible(aiSummarize, 240);
    await tester.pumpAndSettle();
    await tester.tap(aiSummarize);
    await tester.pumpAndSettle();

    // Ringkasan dari fake backend tampil + label "Dihasilkan AI".
    expect(
      find.text(
        'Laskar Pelangi berkisah tentang perjuangan sekolah di Belitung.',
      ),
      findsOneWidget,
    );
    expect(find.text('Dihasilkan AI'), findsOneWidget);
    expect(api.postPaths, contains('/ai/summarize'));

    // Tombol "Tanya AI" membuka SCR-05 dengan konteks buku.
    final aiTanya = find.byKey(const ValueKey<String>('ai-tanya'));
    await tester.scrollUntilVisible(aiTanya, 240);
    await tester.pumpAndSettle();
    await tester.tap(aiTanya);
    await tester.pumpAndSettle();

    expect(find.text('Storyloka AI'), findsOneWidget);
    expect(find.textContaining('Konteks buku aktif'), findsOneWidget);
  });

  testWidgets('TC-25: offline → input dinonaktifkan + banner', (tester) async {
    api = _FakeApi(healthOk: false);
    await pumpApp(tester);

    appRouter.go('/ai');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('ai-input')),
    );
    expect(field.enabled, isFalse);
    expect(find.byKey(const ValueKey<String>('ai-offline')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('TC-25: gagal kirim → pesan + Coba Lagi', (tester) async {
    api = _FakeApi(offlinePost: true);
    await pumpApp(tester);

    appRouter.go('/ai');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('ai-input')),
      'Apa tema cerita ini?',
    );
    await tester.tap(find.byKey(const ValueKey<String>('ai-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('ai-error-text')), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}

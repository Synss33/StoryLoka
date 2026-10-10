import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/app.dart';
import 'package:storyloka/app/router.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/network/api_client.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/biometric_service.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/profile/photo_service.dart';

class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

/// Klien API tiruan: merekam POST dan selalu sukses (online).
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://localhost');

  final List<String> postPaths = <String>[];
  final List<Map<String, Object?>> postBodies = <Map<String, Object?>>[];

  @override
  Future<bool> tryPostJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    postPaths.add(path);
    postBodies.add(body);
    return true;
  }

  @override
  Future<ApiResponse> tryGetJson(String path, {String? token}) async =>
      ApiResponse(
        status: 200,
        body: <String, dynamic>{'feedback': null},
      );
}

/// TC-11: kesan & saran → tersimpan lokal dan terkirim ke web service.
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late _FakeApi api;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_feedback');
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
    store = InMemoryAuthStore()
      ..session = SessionRules.create(user?.id ?? 1);
    appRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStoreProvider.overrideWithValue(store),
          databaseProvider.overrideWith((ref) async => db),
          biometricServiceProvider.overrideWithValue(_NoBiometric()),
          photoPickerProvider.overrideWithValue(_NoPicker()),
          profilePhotoStoreProvider.overrideWithValue(_NoPhotoStore()),
          apiClientProvider.overrideWithValue(api),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-11: isi → Simpan → tersimpan lokal dan terkirim',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Kesan'));
    await tester.pumpAndSettle();
    expect(find.text('SIMPAN / KIRIM'), findsOneWidget);

    // Tombol Simpan berada di bawah lipatan layar — pastikan terlihat dulu.
    await tester.ensureVisible(find.text('SIMPAN / KIRIM'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('field-kesan')),
      'Materi PAM sangat membantu',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('field-saran')),
      'Tambahkan studi kasus tiap minggu',
    );
    await tester.tap(find.text('SIMPAN / KIRIM'));
    await tester.pumpAndSettle();

    // Tampil dua kali: caption status di layar + snackbar.
    expect(find.text('Tersimpan lokal & terkirim.'), findsWidgets);
    expect(api.postPaths, contains('/feedback'));
    expect(api.postBodies.first['kesan'], 'Materi PAM sangat membantu');

    // Lokal: satu baris, sudah ditandai tersinkron.
    final rows = await tester.runAsync(() => db.query('feedback')) ??
        <Map<String, Object?>>[];
    expect(rows, hasLength(1));
    expect(rows.first['kesan'], 'Materi PAM sangat membantu');
    expect(rows.first['saran'], 'Tambahkan studi kasus tiap minggu');
    expect(rows.first['synced'], 1);

    // Isi terakhir tampil ulang saat membuka lagi SCR-10.
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kesan'));
    await tester.pumpAndSettle();
    expect(find.text('Materi PAM sangat membantu'), findsOneWidget);
    expect(find.text('Tambahkan studi kasus tiap minggu'), findsOneWidget);
  });

  testWidgets('TC-11: dua kolom kosong ditolak dengan pesan validasi',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Kesan'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('SIMPAN / KIRIM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIMPAN / KIRIM'));
    await tester.pumpAndSettle();

    expect(
      find.text('Isi minimal satu kolom (kesan atau saran).'),
      findsOneWidget,
    );
    expect(api.postPaths, isEmpty);
  });
}

class _NoPicker implements PhotoPicker {
  @override
  Future<String?> pickFromCamera() async => null;

  @override
  Future<String?> pickFromGallery() async => null;
}

class _NoPhotoStore extends ProfilePhotoStore {
  @override
  Future<String> save(String sourcePath) async => sourcePath;
}

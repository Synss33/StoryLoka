import 'dart:convert';
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

/// 1x1 PNG valid agar dekoder gambar tidak mengeluh di test.
const String pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

class _NoBiometric extends BiometricService {
  @override
  Future<bool> isSupported() async => false;
}

class _FakePicker implements PhotoPicker {
  String? path;

  @override
  Future<String?> pickFromCamera() async => path;

  @override
  Future<String?> pickFromGallery() async => path;
}

/// Tanpa IO nyata: foto "tersimpan" = path hasil pilih.
class _FakePhotoStore extends ProfilePhotoStore {
  @override
  Future<String> save(String sourcePath) async => sourcePath;
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://localhost');

  @override
  Future<bool> tryPostJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async =>
      true;

  @override
  Future<ApiResponse> tryGetJson(String path, {String? token}) async =>
      ApiResponse(
        status: 200,
        body: <String, dynamic>{'feedback': null},
      );
}

/// TC-10: ganti foto profil (kamera/galeri) -> foto tampil di SCR-09 & SCR-02.
void main() {
  late InMemoryAuthStore store;
  late Database db;
  late Directory tempDir;
  late _FakePicker picker;
  late File photoSource;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_edit_profile');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    picker = _FakePicker();
    // Berkas dibuat di setUp (zona nyata) — IO async di dalam testWidgets
    // zona fake-async tidak akan pernah selesai.
    photoSource = File('${tempDir.path}/sumber.png');
    await photoSource.writeAsBytes(base64Decode(pngBase64));
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
          photoPickerProvider.overrideWithValue(picker),
          profilePhotoStoreProvider.overrideWithValue(_FakePhotoStore()),
          apiClientProvider.overrideWithValue(_FakeApi()),
        ],
        child: const StorylokaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
  }

  bool avatarShowing(String path) => find.byWidgetPredicate(
        (w) =>
            w is CircleAvatar &&
            w.backgroundImage is FileImage &&
            (w.backgroundImage! as FileImage).file.path == path,
      ).evaluate().isNotEmpty;

  testWidgets('TC-10: foto galeri tampil di SCR-17, SCR-09, dan Beranda',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Keamanan & Sesi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('edit-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profil'), findsOneWidget);

    // Sumber foto hasil "pemilihan galeri".
    picker.path = photoSource.path;

    await tester.tap(find.byKey(const ValueKey<String>('pick-gallery')));
    await tester.pumpAndSettle();

    // SCR-17 menampilkan foto terpilih sebelum disimpan.
    expect(
      avatarShowing(photoSource.path),
      isTrue,
      reason: 'SCR-17 memakai foto',
    );

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Kembali ke SCR-09 — foto sama tampil di header.
    expect(find.text('Keamanan & Sesi'), findsOneWidget);
    expect(
      avatarShowing(photoSource.path),
      isTrue,
      reason: 'SCR-09 memakai foto',
    );

    // Beranda: avatar di top bar memakai foto yang sama (TC-10).
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Pengguna'), findsOneWidget);
    expect(
      avatarShowing(photoSource.path),
      isTrue,
      reason: 'Beranda memakai foto',
    );
  });

  testWidgets('TC-10: nama hasil edit tersimpan dan tampil di SCR-09',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('edit-profile')));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'Pengguna Uji');
    await tester.enterText(nameField, 'Pembaca Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Pembaca Baru'), findsOneWidget);
    expect(find.text('uji@example.com'), findsOneWidget);
  });
}

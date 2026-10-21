import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/database_provider.dart';
import 'package:storyloka/core/db/game_score_repository.dart';
import 'package:storyloka/core/network/api_client.dart';
import 'package:storyloka/core/network/book_place_service.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_controller.dart';
import 'package:storyloka/features/auth/auth_store.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/explore/explore_screen.dart';

/// Klien API tiruan: menyimpan path/token panggilan & balasan login yang
/// bisa diatur (perbaikan token server — keputusan 54).
class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'http://localhost');

  final List<String> paths = <String>[];
  final List<String?> postTokens = <String?>[];

  /// Token balasan login/register; `null` → balasan tanpa token (offline).
  String? issuedToken = 'srv-token-1';

  /// Register menolak (akun sudah ada di server) → tanpa token.
  bool registerConflict = false;

  @override
  Future<ApiResponse> postJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    paths.add(path);
    postTokens.add(token);
    if (path == '/auth/register') {
      if (registerConflict) {
        return ApiResponse(status: 409, body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'EMAIL_TAK_TERSEDIA',
            'message': 'Sudah terdaftar',
          },
        });
      }
      return ApiResponse(status: 201, body: <String, dynamic>{
        if (issuedToken != null) 'token': issuedToken,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,
        'user': <String, dynamic>{'id': 1, 'email': body['email']},
      });
    }
    if (path == '/auth/login') {
      return ApiResponse(status: 200, body: <String, dynamic>{
        if (issuedToken != null) 'token': issuedToken,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,
        'user': <String, dynamic>{'id': 1, 'email': body['email']},
      });
    }
    if (path == '/auth/logout') {
      return ApiResponse(status: 200, body: <String, dynamic>{'ok': true});
    }
    return ApiResponse(status: 404, body: null);
  }

  @override
  Future<bool> tryPostJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    paths.add(path);
    postTokens.add(token);
    return true;
  }
}

void main() {
  late Directory tempDir;
  late Database db;
  late InMemoryAuthStore store;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_online_mode');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/storyloka.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    store = InMemoryAuthStore();
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

  group('onlineToken', () {
    test('fallback ke token lokal saat token server kosong', () async {
      store.session = SessionRules.create(7);
      expect(await onlineTokenOf(store), store.session!.token);
    });

    test('token server menang bila tersedia', () async {
      store
        ..session = SessionRules.create(7)
        ..serverToken = 'server-abc';
      expect(await onlineTokenOf(store), 'server-abc');
    });
  });

  group('AuthController + token server', () {
    late _RecordingApi api;
    late ProviderContainer container;
    late int userId;

    Future<int> registerLocal() async {
      final user = await UserRepository(db).register(
        name: 'Pengguna Uji',
        email: 'uji@example.com',
        password: 'KataSandi!123',
      );
      return user.id;
    }

    ProviderContainer makeContainer() {
      final c = ProviderContainer(overrides: [
        authStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWith((ref) async => db),
        apiClientProvider.overrideWithValue(api),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      api = _RecordingApi();
      userId = await registerLocal();
      container = makeContainer();
    });

    test('login sukses menyimpan token sesi server (balasan /auth/login)',
        () async {
      final auth = container.read(authControllerProvider.notifier);
      final error =
          await auth.login(identifier: 'uji@example.com', password: 'KataSandi!123');
      expect(error, isNull);

      // Panggilan server bersifat fire-and-forget → dorong antrean mikro.
      await pumpEventQueue();
      expect(store.serverToken, 'srv-token-1',
          reason: 'token balasan login harus dipakai endpoint butuh-auth');
      expect(api.paths, contains('/auth/login'));
    });

    test('register saat akun sudah ada di server (409) → fallback login',
        () async {
      api.registerConflict = true;
      final auth = container.read(authControllerProvider.notifier);
      final error = await auth.register(
        name: 'Pengguna Baru',
        email: 'baru@example.com',
        password: 'KataSandi!123',
        confirm: 'KataSandi!123',
      );
      expect(error, isNull);
      await pumpEventQueue();
      expect(
        api.paths,
        containsAllInOrder(<String>['/auth/register', '/auth/login']),
      );
      expect(store.serverToken, 'srv-token-1',
          reason: 'token harus tetap diperoleh via login setelah 409');
    });

    test('login server gagal/offline → sesi lokal tetap jalan, token kosong',
        () async {
      api.issuedToken = null; // balasan tanpa token (atau status -1)
      final auth = container.read(authControllerProvider.notifier);
      final error =
          await auth.login(identifier: 'uji@example.com', password: 'KataSandi!123');
      expect(error, isNull);
      await pumpEventQueue();
      expect(store.session, isNotNull);
      expect(store.serverToken, isNull);
    });

    test('logout mengirim token server ke /auth/logout lalu menghapusnya',
        () async {
      store
        ..session = SessionRules.create(userId)
        ..serverToken = 'srv-logout';
      container
          .read(authControllerProvider.notifier)
          .adoptSession(userId);

      await container.read(authControllerProvider.notifier).logout();
      await pumpEventQueue();

      expect(store.serverToken, isNull,
          reason: 'token server harus dihapus saat logout');
      final logoutIndex = api.paths.indexOf('/auth/logout');
      expect(logoutIndex, greaterThanOrEqualTo(0));
      expect(api.postTokens[logoutIndex], 'srv-logout',
          reason: 'cabut sesi memakai token server, bukan token lokal');
    });
  });

  group('OverpassBookPlaceService (ketahanan peta)', () {
    test('balasan sukses → daftar tempat, dariCache=false', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'elements': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'node',
                  'lat': -6.2,
                  'lon': 106.8,
                  'tags': <String, dynamic>{
                    'amenity': 'library',
                    'name': 'Perpustakaan Uji',
                    'opening_hours': '08:00-17:00',
                  },
                },
              ],
            },
            ),
            200,
          ));
      final service = OverpassBookPlaceService(client: client);
      final result = await service.nearby(const LatLng(-6.2, 106.8));

      expect(result.fromCache, isFalse);
      expect(result.places, hasLength(1));
      expect(result.places.single.name, 'Perpustakaan Uji');
      expect(result.places.single.isLibrary, isTrue);
      expect(result.places.single.openingHours, '08:00-17:00');
    });

    test('endpoint utama & mirror gagal + tanpa cache → PlacesUnavailable',
        () async {
      final client = MockClient((_) async => http.Response('busy', 500));
      final service = OverpassBookPlaceService(client: client);
      await expectLater(
        service.nearby(const LatLng(-6.2, 106.8)),
        throwsA(isA<PlacesUnavailableException>()),
      );
    });
  });

  group('refresh rekor game (segmen Explore)', () {
    test(
        'tanpa invalidate → nilai basi; invalidate → rekor/koin terbaru',
        () async {
      final user = await UserRepository(db).register(
        name: 'Pengguna Game',
        email: 'game@example.com',
        password: 'KataSandi!123',
      );
      store.session = SessionRules.create(user.id);

      final container = ProviderContainer(overrides: [
        authStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWith((ref) async => db),
      ]);
      addTearDown(container.dispose);
      container
          .read(authControllerProvider.notifier)
          .adoptSession(user.id);

      // Listener aktif = layar Explore yang tetap mounted di balik /game.
      container.listen(gameSummaryProvider, (_, _) {});
      var summary = await container.read(gameSummaryProvider.future);
      expect(summary.bestScore, isNull);
      expect(summary.coins, 0);

      await GameScoreRepository(db).save(
        userId: user.id,
        score: 1000,
        coins: 100,
        playedAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Tanpa invalidasi, provider masih memegang hasil lama (bug basi).
      summary = await container.read(gameSummaryProvider.future);
      expect(summary.bestScore, isNull,
          reason: 'provider cache nilai lama — inilah akar rekor basi');

      // Inilah yang dilakukan GameScreen._finishRound (perbaikan).
      container.invalidate(gameSummaryProvider);
      summary = await container.read(gameSummaryProvider.future);
      expect(summary.bestScore, 1000);
      expect(summary.coins, 100);
    });
  });
}

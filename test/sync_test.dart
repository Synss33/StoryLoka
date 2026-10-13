import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/models/book.dart';
import 'package:storyloka/core/network/api_client.dart';
import 'package:storyloka/core/network/sync_service.dart';
import 'package:storyloka/core/security/session.dart';
import 'package:storyloka/features/auth/auth_store.dart';

/// Klien jaringan tiruan — bisa di-set offline/online dan
/// merekam payload yang dikirim (tanpa HTTP sungguhan pada unit test).
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://localhost');

  bool online = false;

  /// Balasan yang akan diberikan saat [online].
  Map<String, dynamic> response = <String, dynamic>{};

  final List<Map<String, Object?>> sentBodies = [];
  final List<String?> sentTokens = [];

  @override
  Future<ApiResponse> postJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    if (!online) return const ApiResponse(status: -1);
    sentBodies.add(body);
    sentTokens.add(token);
    return ApiResponse(status: 200, body: response);
  }
}

/// TC-29: tambah buku saat offline → antrean; kembali online → terkirim
/// ke server dan ditandai tersinkron (workflow §3.7).
void main() {
  late Directory tempDir;
  late Database db;
  late BookRepository repo;
  late FakeApiClient client;
  late SyncService service;
  late InMemoryAuthStore store;

  const userId = 1;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storyloka_sync');
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
    client = FakeApiClient();
    store = InMemoryAuthStore()..session = SessionRules.create(userId);
    service = SyncService(db: db, client: client, store: store);
  });

  tearDown(() async {
    service.dispose();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('TC-29: buku offline masuk antrean, terkirim saat kembali online',
      () async {
    // 1. Offline: tambah buku → dirty, sinkronisasi gagal, antrean bertahan.
    final id = await repo.insert(
      Book(userId: userId, title: 'Buku Offline', updatedAt: 0),
    );
    expect(await service.hasPending(), isTrue);

    final gagal = await service.syncNow();
    expect(gagal, isFalse, reason: 'server tak terjangkau → gagal');
    expect((await repo.get(id))!.dirty, isTrue, reason: 'antrean tidak hilang');
    expect(client.sentBodies, isEmpty);

    // 2. Kembali online: sinkron berikutnya sukses.
    client.online = true;
    final buku = (await repo.get(id))!;
    client.response = <String, dynamic>{
      'serverTime': 1700000000000,
      'books': [buku.toJson()],
      'sessions': <Object>[],
      'notes': <Object>[],
      'reviews': <Object>[],
      'blocks': <Object>[],
      'feedback': <Object>[],
      'settings': null,
    };

    final sukses = await service.syncNow();
    expect(sukses, isTrue);
    expect(client.sentBodies, hasLength(1));
    expect(client.sentTokens.first, isNotEmpty, reason: 'token sesi dikirim');
    final terkirim = (client.sentBodies.first['books'] as List).first;
    expect(terkirim['title'], 'Buku Offline');

    // 3. Setelah diterima server → tidak lagi dirty, antrean kosong.
    expect((await repo.get(id))!.dirty, isFalse);
    expect(await service.hasPending(), isFalse);
  });

  test('balasan server yang lebih baru menang (LWW dua arah)', () async {
    final id = await repo.insert(
      Book(userId: userId, title: 'Lokal', updatedAt: 0),
    );
    final lokal = await repo.get(id);

    client.online = true;
    client.response = <String, dynamic>{
      'serverTime': 1700000000000,
      'books': [
        <String, Object?>{
          'id': id,
          'user_id': userId,
          'title': 'Dari Server',
          'author': 'Server',
          'status': 'completed',
          'updated_at': lokal!.updatedAt + 60000,
          'deleted': 0,
        },
      ],
    };

    expect(await service.syncNow(), isTrue);
    final stored = await repo.get(id);
    expect(stored!.title, 'Dari Server', reason: 'server lebih baru → menang');
    expect(stored.dirty, isFalse);
    expect(await service.hasPending(), isFalse);
  });

  test('tanpa sesi login: sinkronisasi tidak mengirim apa pun', () async {
    await repo.insert(Book(userId: userId, title: 'Buku', updatedAt: 0));
    client.online = true;
    store.session = null;

    expect(await service.syncNow(), isFalse);
    expect(client.sentBodies, isEmpty);
  });

  test('kick: gagal offline → jadwalkan coba ulang, sukses → bersih', () async {
    await repo.insert(Book(userId: userId, title: 'Antre', updatedAt: 0));
    client.online = false;

    service.kick(); // gagal → backoff terjadwal
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await service.hasPending(), isTrue);

    // Server hidup sebelum backoff: panggilan manual langsung memproses.
    client.online = true;
    client.response = <String, dynamic>{'serverTime': 1, 'books': <Object>[]};
    expect(await service.syncNow(), isTrue);
    expect(await service.hasPending(), isFalse);
    service.dispose(); // batalkan sisa timer backoff
  });
}

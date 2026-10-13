import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/book_repository.dart';
import 'package:storyloka/core/models/book.dart';

/// Uji CRUD buku offline + penanda `dirty` (F-04, WF-03).
void main() {
  late Directory tempDir;
  late Database db;
  late BookRepository repo;

  const userId = 1;

  Book buku({int? id, String title = 'Laskar Pelangi', bool dirty = true}) =>
      Book(
        id: id,
        userId: userId,
        title: title,
        author: 'Andrea Hirata',
        status: 'reading',
        updatedAt: 0,
        dirty: dirty,
      );

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storyloka_books');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/t.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    // User pemilik (FK books.user_id → users.id).
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

  test('insert: buku tersimpan dirty=1 dengan updated_at terisi', () async {
    final id = await repo.insert(buku());
    final saved = await repo.get(id);
    expect(saved, isNotNull);
    expect(saved!.dirty, isTrue);
    expect(saved.updatedAt, greaterThan(0));
    expect(saved.title, 'Laskar Pelangi');
  });

  test('update & soft delete: selalu menandai dirty (antrean sinkron)', () async {
    final id = await repo.insert(buku());
    await repo.update(
      (await repo.get(id))!.copyWithTitle('Judul Baru'),
    );
    var stored = await repo.get(id);
    expect(stored!.title, 'Judul Baru');
    expect(stored.dirty, isTrue);
    expect(stored.deleted, isFalse);

    await repo.softDelete(id);
    stored = await repo.get(id);
    expect(stored!.deleted, isTrue);
    expect(stored.dirty, isTrue);
    // Default list menyembunyikan yang terhapus; includeDeleted menampilkannya.
    expect(
      (await repo.list(userId)).where((b) => b.id == id),
      isEmpty,
    );
    expect(
      (await repo.list(userId, includeDeleted: true)).where((b) => b.id == id),
      hasLength(1),
    );
  });

  test('pendingSync: hanya buku dirty yang masuk antrean', () async {
    final id1 = await repo.insert(buku(title: 'Satu'));
    final id2 = await repo.insert(buku(title: 'Dua'));
    await repo.markSynced([id1]);

    final pending = await repo.pendingSync(userId);
    expect(pending.map((b) => b.id), [id2]);
  });

  test('applyServer LWW: server lebih baru mengganti, lebih lama kalah', () async {
    final id = await repo.insert(buku(title: 'Lokal Lama'));

    // Server lebih lama → lokal menang (judul tetap), tetap ditandai synced.
    await repo.applyServer(
      buku(id: id, title: 'Server Basi').copyWithUpdatedAt(1),
    );
    var stored = await repo.get(id);
    expect(stored!.title, 'Lokal Lama');
    expect(stored.dirty, isFalse);

    // Server lebih baru → data server yang menang.
    await repo.applyServer(
      buku(id: id, title: 'Server Segar').copyWithUpdatedAt(
        stored.updatedAt + 1000,
      ),
    );
    stored = await repo.get(id);
    expect(stored!.title, 'Server Segar');
    expect(stored.dirty, isFalse);
  });

  test('applyServer: id baru dari server ikut tersimpan', () async {
    await repo.applyServer(
      Book(
        id: 99,
        userId: userId,
        title: 'Dari Device Lain',
        updatedAt: 5000,
        dirty: false,
      ),
    );
    expect((await repo.get(99))?.title, 'Dari Device Lain');
  });
}

extension on Book {
  Book copyWithTitle(String title) =>
      Book(id: id, userId: userId, title: title, author: author, status: status, updatedAt: updatedAt, dirty: dirty);

  Book copyWithUpdatedAt(int updatedAt) => Book(
        id: id,
        userId: userId,
        title: title,
        author: author,
        status: status,
        updatedAt: updatedAt,
        dirty: dirty,
      );
}

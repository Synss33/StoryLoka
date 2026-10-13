import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/schema.dart';
import 'package:storyloka/core/security/db_key_store.dart';

/// Unit test fondasi WF-01:
/// 1. generator kunci enkripsi 256-bit;
/// 2. pembukaan skema DB v1 (11 tabel), penulisan, dan pembacaan satu baris.
///
/// Catatan: SQLCipher hanya tersedia di Android/iOS/macOS. Di host Windows
/// test memakai `sqflite_common_ffi` (SQLite polos) sehingga yang diuji
/// adalah skema + alur tulis/baca; kebuka-terenkripsi diverifikasi pada
/// perangkat/emulator (lihat `docs/keputusan.md`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Kunci database', () {
    test('generateDbKey menghasilkan 64 heksadesimal (256 bit) dan acak',
        () {
      final key = DbKeyStore.generateDbKey();
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
      // Dua kali dibuat harus berbeda (acak, bukan konstanta).
      expect(DbKeyStore.generateDbKey(), isNot(equals(key)));
    });
  });

  group('Skema database v1', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storyloka_db_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('membuat 11 tabel, menulis, dan membaca satu baris', () async {
      final path = '${tempDir.path}/${AppDatabase.fileName}';
      final db = await openStorylokaDatabase(
        path: path,
        // Password tetap dikirim agar alur pemanggilan produksi sama;
        // pabrik ffi mengabaikannya (lihat catatan di atas).
        password: DbKeyStore.generateDbKey(),
        factory: databaseFactoryFfi,
      );

      // Versi skema sesuai migrasi v1.
      expect(await db.getVersion(), AppDatabase.version);

      // Seluruh tabel dari deskripsi proyek Bagian 5.2 tersedia.
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();
      expect(
        names,
        containsAll(<String>[
          'users',
          'books',
          'reading_sessions',
          'notes_quotes',
          'reviews',
          'blocks',
          'feedback',
          'settings',
          'game_scores',
          'notifications',
          'rate_cache',
        ]),
      );

      // Menulis satu baris pengguna + satu baris buku.
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = await db.insert('users', <String, Object?>{
        'name': 'Pengguna Uji',
        'email': 'uji@storyloka.local',
        'password_hash': 'hash-tidak-pernah-polos',
        'salt': 'salt-acak',
        'kdf_params': '{"algo":"argon2id"}',
        'created_at': now,
        'updated_at': now,
      });
      expect(userId, 1);

      final bookId = await db.insert('books', <String, Object?>{
        'user_id': userId,
        'title': 'Laskar Pelangi',
        'author': 'Andrea Hirata',
        'pages': 529,
        'status': 'reading',
        'updated_at': now,
        'dirty': 1,
      });

      // Membaca kembali satu baris.
      final rows = await db.query(
        'books',
        columns: ['title', 'author', 'pages', 'status'],
        where: 'id = ?',
        whereArgs: <Object>[bookId],
      );
      expect(rows, hasLength(1));
      expect(rows.first['title'], 'Laskar Pelangi');
      expect(rows.first['author'], 'Andrea Hirata');
      expect(rows.first['pages'], 529);
      expect(rows.first['status'], 'reading');

      await db.close();
    });

    test('status buku di luar daftar CHECK ditolak oleh database', () async {
      final path = '${tempDir.path}/${AppDatabase.fileName}';
      final db = await openStorylokaDatabase(
        path: path,
        password: DbKeyStore.generateDbKey(),
        factory: databaseFactoryFfi,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = await db.insert('users', <String, Object?>{
        'name': 'Uji',
        'email': 'uji2@storyloka.local',
        'password_hash': 'x',
        'salt': 'x',
        'kdf_params': '{}',
        'created_at': now,
        'updated_at': now,
      });

      expect(
        () => db.insert('books', <String, Object?>{
          'user_id': userId,
          'title': 'Buku',
          'author': 'Penulis',
          'status': 'dibaca',
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    });
  });
}

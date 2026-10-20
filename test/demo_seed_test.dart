import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/core/blockchain/hash_chain.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/models/block.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/features/auth/demo_seed.dart';
import 'package:storyloka/features/auth/user_repository.dart';

/// Uji seeder akun demo (keputusan 52): idempoten, data lengkap,
/// dan rantai hash blok valid.
void main() {
  late Directory tempDir;
  late Database db;

  setUp(() async {
    PasswordHasher.iterations = 1000;
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('storyloka_demo_test');
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

  test('DemoSeeder membuat akun + data contoh yang lengkap', () async {
    final userId = await DemoSeeder(db).ensure();

    final user = await UserRepository(db).findByEmailOrName(DemoSeeder.email);
    expect(user, isNotNull);
    expect(user!.id, userId);
    expect(
      await UserRepository(db).verifyPassword(user, DemoSeeder.password),
      isTrue,
    );

    Future<int> countSessions() async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM reading_sessions WHERE book_id IN '
        '(SELECT id FROM books WHERE user_id = ?)',
        [userId],
      );
      return rows.first['n'] as int;
    }

    Future<int> countByBook(String table) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM $table WHERE book_id IN '
        '(SELECT id FROM books WHERE user_id = ?)',
        [userId],
      );
      return rows.first['n'] as int;
    }

    Future<int> countUser(String table) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM $table WHERE user_id = ?',
        [userId],
      );
      return rows.first['n'] as int;
    }

    final books = await db.query(
      'books',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    expect(books.length, greaterThanOrEqualTo(10));

    final completed = books.where((b) => b['status'] == 'completed');
    expect(completed.length, greaterThanOrEqualTo(5));
    expect(books.where((b) => b['status'] == 'reading'), hasLength(2));
    expect(books.where((b) => b['status'] == 'wishlist'), hasLength(2));

    expect(await countSessions(), greaterThanOrEqualTo(10));
    expect(await countByBook('notes_quotes'), greaterThanOrEqualTo(3));
    expect(await countByBook('reviews'), completed.length);
    expect(await countUser('blocks'), completed.length);
    expect(await countUser('game_scores'), 3);

    final feedback = await db.query(
      'feedback',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    expect(feedback, hasLength(1));

    final settings = await db.query(
      'settings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    expect(settings.single['monthly_target'], 4);
  });

  test('DemoSeeder idempoten — panggil ulang tidak menggandakan data', () async {
    final first = await DemoSeeder(db).ensure();
    final booksAfterFirst = await db.query(
      'books',
      where: 'user_id = ?',
      whereArgs: [first],
    );

    final second = await DemoSeeder(db).ensure();
    expect(second, first);

    final booksAfterSecond = await db.query(
      'books',
      where: 'user_id = ?',
      whereArgs: [first],
    );
    expect(booksAfterSecond.length, booksAfterFirst.length);
  });

  test('rantai blok demo valid (Proof of Reading)', () async {
    final userId = await DemoSeeder(db).ensure();
    final rows = await db.query(
      'blocks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'idx ASC',
    );
    expect(rows, isNotEmpty);

    final blocks = rows.map(Block.fromRow).toList();
    expect(HashChain.validate(blocks).valid, isTrue);
  });
}

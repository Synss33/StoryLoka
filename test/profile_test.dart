import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:storyloka/app/theme_mode_provider.dart';
import 'package:storyloka/core/db/app_database.dart';
import 'package:storyloka/core/db/settings_repository.dart';
import 'package:storyloka/core/security/password_hasher.dart';
import 'package:storyloka/features/auth/user_repository.dart';
import 'package:storyloka/features/profile/photo_service.dart';

/// Pengujian unit lapisan data SCR-09/SCR-17 (WF-04):
/// update profil & password, simpan foto, persistensi tema.
void main() {
  late Directory tempDir;
  late Database db;
  late UserRepository repo;
  late int userId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    PasswordHasher.iterations = 1000;
    tempDir = await Directory.systemTemp.createTemp('storyloka_profile');
    db = await openStorylokaDatabase(
      path: '${tempDir.path}/t.db',
      password: '0' * 64,
      factory: databaseFactoryFfiNoIsolate,
    );
    repo = UserRepository(db);
    final user = await repo.register(
      name: 'Ayu Lestari',
      email: 'ayu@example.com',
      password: 'KataSandi!123',
    );
    userId = user.id;
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

  test('updateProfile mengubah nama, email, dan foto (SCR-17)', () async {
    await repo.updateProfile(
      id: userId,
      name: 'Ayu Baru',
      email: 'AYU@Example.com',
      photoPath: '${tempDir.path}/profile_photo.png',
    );

    final updated = await repo.byId(userId);
    expect(updated?.name, 'Ayu Baru');
    expect(updated?.email, 'ayu@example.com'); // dinormalkan huruf kecil
    expect(updated?.photoPath, '${tempDir.path}/profile_photo.png');
  });

  test('updateProfile menolak email yang sudah dipakai', () async {
    await repo.register(
      name: 'Lain',
      email: 'lain@example.com',
      password: 'KataSandi!123',
    );
    expect(
      () => repo.updateProfile(
        id: userId,
        name: 'Ayu',
        email: 'lain@example.com',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('sudah dipakai'),
        ),
      ),
    );
  });

  test('updatePassword memverifikasi password lama lalu menulis hash baru',
      () async {
    expect(
      () => repo.updatePassword(
        id: userId,
        currentPassword: 'Salah!',
        newPassword: 'Baru12345',
      ),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Password lama salah'),
        ),
      ),
    );

    await repo.updatePassword(
      id: userId,
      currentPassword: 'KataSandi!123',
      newPassword: 'Baru12345',
    );

    final user = await repo.findByEmailOrName('ayu@example.com');
    expect(user, isNotNull);
    expect(await repo.verifyPassword(user!, 'Baru12345'), isTrue);
    expect(await repo.verifyPassword(user, 'KataSandi!123'), isFalse);
  });

  test('ProfilePhotoStore menyalin foto terpilih ke direktori aplikasi',
      () async {
    final source = File('${tempDir.path}/picked.jpg');
    await source.writeAsBytes(utf8.encode('isi-foto-sampel'));

    final store = ProfilePhotoStore(directory: tempDir);
    final saved = await store.save(source.path);

    expect(saved, p.join(tempDir.path, 'profile_photo.jpg'));
    expect(await File(saved).exists(), isTrue);
  });

  test('tema tersimpan di settings dan dibaca kembali (SCR-09)', () async {
    final settings = SettingsRepository(db);

    await settings.setThemeMode(userId, 'dark');
    final stored = await settings.read(userId);
    expect(stored?.themeMode, 'dark');
    expect(StorylokaThemeMode.fromStorage(stored?.themeMode),
        StorylokaThemeMode.gelap);

    await settings.setThemeMode(userId, 'light');
    final relit = await settings.read(userId);
    expect(relit?.themeMode, 'light');
    expect(StorylokaThemeMode.fromStorage(relit?.themeMode),
        StorylokaThemeMode.terang);

    // Nilai tidak dikenal jatuh kembali ke otomatis.
    expect(StorylokaThemeMode.fromStorage('aneh'), StorylokaThemeMode.auto);
  });
}

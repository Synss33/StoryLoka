import 'package:sqflite_sqlcipher/sqflite.dart';

import 'schema.dart';

/// Pembuka database terenkripsi Storyloka.
///
/// * Produksi (Android/iOS): `sqflite_sqlcipher` dengan **kunci acak
///   256-bit** dari [DbKeyStore] (lihat `lib/core/security/db_key_store.dart`),
///   bukan diturunkan dari password pengguna.
/// * Unit test di host Windows: SQLCipher tidak tersedia, maka pabrik
///   (`databaseFactoryFfi`) boleh disuntikkan dan password diabaikan —
///   yang diuji adalah skema, tulis, dan baca (lihat `test/db_test.dart`).
Future<Database> openStorylokaDatabase({
  required String path,
  required String password,
  DatabaseFactory? factory,
}) async {
  if (factory != null) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabase.version,
        onConfigure: AppDatabase.onConfigure,
        onCreate: AppDatabase.onCreate,
        onUpgrade: AppDatabase.onUpgrade,
      ),
    );
  }

  return openDatabase(
    path,
    password: password,
    version: AppDatabase.version,
    onConfigure: AppDatabase.onConfigure,
    onCreate: AppDatabase.onCreate,
    onUpgrade: AppDatabase.onUpgrade,
  );
}

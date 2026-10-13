import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/db_key_store.dart';
import 'app_database.dart';
import 'schema.dart';

/// Membuka database terenkripsi Storyloka saat aplikasi pertama berjalan.
///
/// Kunci diambil dari secure storage (dibuat acak 256-bit, bukan dari
/// password). Bila platform tidak mendukung plugin (mis. unit test di host)
/// provider ini gagal diam-diam dan mengembalikan `null` — logika bisnis
/// tidak ada di sini, hanya pembukaan sumber data.
final databaseProvider = FutureProvider<Database?>((ref) async {
  try {
    final key = await DbKeyStore.getOrCreateKey();
    final path = p.join(await getDatabasesPath(), AppDatabase.fileName);
    final db = await openStorylokaDatabase(path: path, password: key);
    ref.onDispose(db.close);
    debugPrint('[db] database terbuka: ${AppDatabase.fileName} (v${AppDatabase.version})');
    return db;
  } catch (e) {
    debugPrint('[db] database tidak dapat dibuka: $e');
    return null;
  }
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../utils/currency.dart';
import 'database_provider.dart';

/// Akses tabel `rate_cache` (F-17 — Bagian 5.12): kurs terakhir yang
/// pernah diterima dari `GET /rates`, dipakai kembali saat offline.
class RateCacheRepository {
  RateCacheRepository(this._db);

  final Database _db;

  /// Menyimpan seluruh kurs dalam satu snapshot (upsert per mata uang).
  Future<void> saveSnapshot(RateSnapshot snapshot) async {
    final batch = _db.batch();
    for (final entry in snapshot.rates.entries) {
      batch.insert(
        'rate_cache',
        <String, Object>{
          'currency': entry.key,
          'rate_to_idr': entry.value,
          'fetched_at': snapshot.fetchedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Membaca snapshot kurs terakhir; `null` bila cache masih kosong.
  Future<RateSnapshot?> readLatest() async {
    final rows = await _db.query('rate_cache');
    if (rows.isEmpty) return null;
    var fetchedAt = 0;
    final rates = <String, double>{};
    for (final row in rows) {
      rates[row['currency'] as String] = (row['rate_to_idr'] as num).toDouble();
      final at = row['fetched_at'] as int;
      if (at > fetchedAt) fetchedAt = at;
    }
    return RateSnapshot(rates: rates, fetchedAt: fetchedAt);
  }
}

final rateCacheRepositoryProvider =
    FutureProvider<RateCacheRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return RateCacheRepository(db);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/rate_cache_repository.dart';
import '../utils/currency.dart';
import '../../features/auth/auth_store.dart';
import 'api_client.dart';

/// Hasil pengambilan kurs: snapshot + sumber ("server" / "cache").
class RatesResult {
  const RatesResult({required this.snapshot, required this.fromCache});

  final RateSnapshot snapshot;

  /// `true` bila data berasal dari cache lokal (server tak terjangkau).
  final bool fromCache;
}

/// Pengambil kurs (F-17): `GET /rates` dari backend, hasil terakhir
/// di-cache di tabel `rate_cache` untuk dipakai ulang saat offline
/// (deskripsi Bagian 5.12 — "cache untuk offline").
class RatesService {
  RatesService({required this.client, required this.cache});

  final ApiClient client;
  final RateCacheRepository cache;

  /// Mengambil kurs terbaru. Bila server tak terjangkau, jatuh ke cache;
  /// kembalian `null` bila keduanya kosong (pengguna offline pertama kali).
  Future<RatesResult?> fetch({String? token}) async {
    final response = await client.tryGetJson('/rates', token: token);
    final snapshot = RateSnapshot.fromApi(response.body);
    if (snapshot != null && response.ok) {
      await cache.saveSnapshot(snapshot);
      return RatesResult(snapshot: snapshot, fromCache: false);
    }
    final cached = await cache.readLatest();
    if (cached == null) return null;
    return RatesResult(snapshot: cached, fromCache: true);
  }
}

/// Mengambil token sesi berjalan untuk panggilan `/rates` (requireAuth).
Future<String?> _currentToken(Ref ref) async {
  final session = await ref.read(authStoreProvider).readSession();
  return session?.token;
}

/// Provider repository cache kurs (null bila DB belum terbuka).
final ratesServiceProvider = FutureProvider<RatesService?>((ref) async {
  final client = ref.watch(apiClientProvider);
  final cache = await ref.watch(rateCacheRepositoryProvider.future);
  if (cache == null) return null;
  return RatesService(client: client, cache: cache);
});

/// Provider asinkron kurs terbaru — dipakai SCR-04 Konverter.
/// Menonton [ratesServiceProvider]; refresh dengan `ref.invalidateSelf()`.
final ratesProvider = FutureProvider<RatesResult?>((ref) async {
  final service = await ref.watch(ratesServiceProvider.future);
  if (service == null) return null;
  final token = await _currentToken(ref);
  return service.fetch(token: token);
});

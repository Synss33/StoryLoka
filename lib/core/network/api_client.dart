import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Hasil pemeriksaan endpoint `GET /health`.
class HealthStatus {
  const HealthStatus({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// Klien REST API dasar.
///
/// Alamat server diambil dari konfigurasi build (`--dart-define`),
/// **bukan** ditulis tetap di kode:
///
/// ```sh
/// # emulator Android (default)
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
/// # perangkat fisik / emulator lain (IP komputer yang menjalankan backend)
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
/// ```
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl;

  /// Nilai bawaan: loopback host dari emulator Android ke mesin lokal.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);

  /// `GET /health` — dipakai untuk memastikan aplikasi terhubung ke backend
  /// (Definition of Done WF-01).
  Future<HealthStatus> getHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return const HealthStatus(
          ok: true,
          message: 'Backend terhubung (/health OK)',
        );
      }
      return HealthStatus(
        ok: false,
        message: 'Backend membalas HTTP ${response.statusCode}',
      );
    } catch (e) {
      return HealthStatus(
        ok: false,
        message: 'Backend tidak terjangkau ($baseUrl)',
      );
    }
  }

  void close() => _client.close();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

/// Status kesehatan backend; dipantau di SCR-02 (Beranda).
final healthProvider = FutureProvider<HealthStatus>((ref) {
  return ref.watch(apiClientProvider).getHealth();
});

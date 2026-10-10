import 'dart:convert';

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

  /// `POST` JSON **tanpa menunggu hasil** ke UI: dipakai panggilan pendukung
  /// (registrasi/login ke server, sinkronisasi WF-03) yang sah gagal saat
  /// offline. Mengembalikan `true` hanya bila server membalas 2xx.
  Future<bool> tryPostJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: <String, String>{
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Offline / server mati: diabaikan — data lokal tetap sumber utama.
      return false;
    }
  }

  /// `POST` JSON dan **mengembalikan hasilnya** — dipakai sinkronisasi
  /// (WF-03) yang perlu tahu isi balasan server.
  ///
  /// [status] `-1` = gagal jaringan/timeout (dianggap offline);
  /// `0` = balasan bukan JSON.
  Future<ApiResponse> postJson(
    String path, {
    required Map<String, Object?> body,
    String? token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: <String, String>{
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return ApiResponse(
          status: response.statusCode,
          body: decoded is Map<String, dynamic> ? decoded : null,
        );
      } catch (_) {
        return ApiResponse(status: response.statusCode, body: null, invalidJson: true);
      }
    } catch (_) {
      return const ApiResponse(status: -1);
    }
  }

  void close() => _client.close();
}

/// Balasan `postJson` yang sudah dinormalisasi.
class ApiResponse {
  const ApiResponse({required this.status, this.body, this.invalidJson = false});

  /// Kode HTTP; `-1` bila jaringan gagal, `0` bila bukan JSON.
  final int status;

  /// Body JSON berbentuk objek (null bila tidak ada / bukan objek).
  final Map<String, dynamic>? body;

  /// true bila server membalas bukan JSON.
  final bool invalidJson;

  bool get ok => status >= 200 && status < 300;

  /// Kondisi "server tidak terjangkau" (offline / timeout).
  bool get offline => status == -1;
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_store.dart';
import 'api_client.dart';

/// Kegagalan permintaan AI yang sudah dinormalisasi (workflow 3.5).
enum AiFailure {
  /// Jaringan/timeout klien — dianggap offline.
  offline,

  /// Kuota Gemini habis (HTTP 429).
  quota,

  /// API key belum diatur di server (HTTP 503 `AI_DISABLED`).
  disabled,

  /// Server membalas galat lain (timeout upstream, dsb.) — bisa dicoba lagi.
  error,
}

/// Hasil satu permintaan AI: `text` terisi bila sukses, `failure` bila gagal.
class AiResult {
  const AiResult.ok(this.text)
      : failure = null,
        message = '';

  const AiResult.failed(this.failure, this.message) : text = null;

  final String? text;
  final AiFailure? failure;
  final String message;

  bool get ok => text != null;
}

/// Klien proxy AI (F-11 / WF-07): `POST /ai/*` ke backend, API key tetap
/// di server. Setiap kegagalan dipetakan ke [AiFailure] agar SCR-05/06 bisa
/// menampilkan offline / kuota / coba-lagi dengan pesan yang jelas.
class AiService {
  AiService({required this.client});

  final ApiClient client;

  Future<AiResult> chat({
    required String message,
    List<Map<String, String>> history = const <Map<String, String>>[],
    String? context,
    String? token,
  }) async {
    final response = await client.postJson(
      '/ai/chat',
      body: <String, Object?>{
        'message': message,
        if (history.isNotEmpty) 'history': history,
        if (context != null && context.isNotEmpty) 'context': context,
      },
      token: token,
    );
    return _map(response, const <String>['reply']);
  }

  Future<AiResult> summarize({
    required String title,
    String? author,
    String? synopsis,
    List<String> notes = const <String>[],
    String? token,
  }) async {
    final response = await client.postJson(
      '/ai/summarize',
      body: <String, Object?>{
        'title': title,
        ?author: author,
        if (synopsis != null && synopsis.isNotEmpty) 'synopsis': synopsis,
        if (notes.isNotEmpty) 'notes': notes,
      },
      token: token,
    );
    return _map(response, const <String>['summary']);
  }

  Future<AiResult> recommend({
    required List<Map<String, Object?>> books,
    String? token,
  }) async {
    final response = await client.postJson(
      '/ai/recommend',
      body: <String, Object?>{'books': books},
      token: token,
    );
    return _map(response, const <String>['recommendations']);
  }

  /// Memetakan [ApiResponse] ke [AiResult] (kode galat backend: `error.code`).
  AiResult _map(ApiResponse response, List<String> textKeys) {
    if (response.offline) {
      return const AiResult.failed(AiFailure.offline, 'Tidak ada koneksi.');
    }
    final body = response.body;
    if (!response.ok || body == null) {
      final error = body?['error'];
      final code = error is Map<String, dynamic> ? error['code'] : null;
      final serverMessage = error is Map<String, dynamic>
          ? error['message'] as String?
          : null;
      if (code == 'AI_QUOTA' || response.status == 429) {
        return AiResult.failed(
          AiFailure.quota,
          serverMessage ?? 'Kuota AI habis. Coba lagi nanti.',
        );
      }
      if (code == 'AI_DISABLED' || response.status == 503) {
        return AiResult.failed(
          AiFailure.disabled,
          serverMessage ?? 'Layanan AI belum tersedia.',
        );
      }
      if (response.invalidJson || body == null) {
        return const AiResult.failed(
          AiFailure.error,
          'Balasan server tidak terbaca. Coba lagi.',
        );
      }
      return AiResult.failed(
        AiFailure.error,
        serverMessage ?? 'Gagal menghubungi AI. Coba lagi.',
      );
    }
    for (final key in textKeys) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) {
        return AiResult.ok(value.trim());
      }
    }
    return const AiResult.failed(
      AiFailure.error,
      'AI tidak memberi jawaban. Coba lagi.',
    );
  }
}

/// Token sesi untuk endpoint `/ai/*` (requireAuth): token server dulu,
/// cadangan token lokal (offline / test host).
Future<String?> aiToken(Ref ref) => onlineToken(ref);

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(client: ref.watch(apiClientProvider));
});

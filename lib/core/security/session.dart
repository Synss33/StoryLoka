import 'dart:convert';
import 'dart:math';

/// Model sesi login (deskripsi proyek Bagian 5.1):
/// token acak tidak dapat ditebak + masa berlaku default 7 hari.
class SessionInfo {
  const SessionInfo({
    required this.token,
    required this.userId,
    required this.expiresAt,
  });

  final String token;
  final int userId;

  /// Epoch millisecond (UTC) — konsisten dengan konvensi waktu database.
  final int expiresAt;

  /// Sesi dianggap berakhir bila [expiresAt] sudah lewat dari [now].
  bool isExpired({DateTime? now}) {
    final clock = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return clock >= expiresAt;
  }

  String toJson() =>
      jsonEncode(<String, Object>{'token': token, 'userId': userId, 'expiresAt': expiresAt});

  static SessionInfo? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return SessionInfo(
        token: map['token'] as String,
        userId: map['userId'] as int,
        expiresAt: map['expiresAt'] as int,
      );
    } catch (_) {
      // Data rusak dianggap tidak ada sesi → paksa login ulang.
      return null;
    }
  }
}

/// Aturan pembuatan sesi.
abstract final class SessionRules {
  /// Masa berlaku token sesi (deskripsi Bagian 5.1: default 7 hari).
  static const Duration lifetime = Duration(days: 7);

  /// Token acak 32 byte (64 heksadesimal) via CSPRNG OS.
  static String newToken() {
    final rng = Random.secure();
    return List<int>.generate(32, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Membuat sesi baru untuk [userId] dengan waktu berlaku [now] + [lifetime].
  static SessionInfo create(int userId, {DateTime? now}) {
    final start = now ?? DateTime.now();
    return SessionInfo(
      token: newToken(),
      userId: userId,
      expiresAt: start.add(lifetime).millisecondsSinceEpoch,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../core/db/database_provider.dart';
import '../../features/auth/auth_controller.dart';

/// Statistik ringkas profil (SCR-09 — "28 Buku · 96 Jam · 5 Sertifikat ·
/// 120🪙"). Semua angka dihitung dari tabel lokal (F-07).
class ProfileStats {
  const ProfileStats({
    required this.booksRead,
    required this.hoursRead,
    required this.certificates,
    required this.coins,
  });

  /// Jumlah buku berstatus `completed` (soft delete dikecualikan).
  final int booksRead;

  /// Total jam membaca (dibulatkan) dari seluruh sesi.
  final int hoursRead;

  /// Jumlah blok hash "Proof of Reading".
  final int certificates;

  /// Total koin game trivia.
  final int coins;

  static Future<ProfileStats> load(Database db, int userId) async {
    Future<int> scalar(String sql, List<Object?> args) async {
      final rows = await db.rawQuery(sql, args);
      if (rows.isEmpty || rows.first.values.isEmpty) return 0;
      final value = rows.first.values.first;
      if (value is! num) return 0;
      return value.toInt();
    }

    final booksRead = await scalar(
      "SELECT COUNT(*) FROM books "
      'WHERE user_id = ? AND status = \'completed\' AND deleted = 0',
      <Object?>[userId],
    );
    // Sesi tidak punya kolom user_id — dijumlahkan lewat buku milik pengguna.
    final durationSec = await scalar(
      'SELECT COALESCE(SUM(s.duration_sec), 0) FROM reading_sessions s '
      'JOIN books b ON s.book_id = b.id '
      'WHERE b.user_id = ? AND b.deleted = 0',
      <Object?>[userId],
    );
    final certificates = await scalar(
      'SELECT COUNT(*) FROM blocks WHERE user_id = ?',
      <Object?>[userId],
    );
    final coins = await scalar(
      'SELECT COALESCE(SUM(coins), 0) FROM game_scores WHERE user_id = ?',
      <Object?>[userId],
    );

    return ProfileStats(
      booksRead: booksRead,
      hoursRead: (durationSec / 3600).round(),
      certificates: certificates,
      coins: coins,
    );
  }
}

/// Statistik pengguna aktif (null bila belum ada sesi/DB).
final profileStatsProvider = FutureProvider.autoDispose<ProfileStats?>((ref) {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) return Future<ProfileStats?>.value();
  return ref.watch(databaseProvider.future).then((db) async {
    if (db == null) return null;
    return ProfileStats.load(db, userId);
  });
});

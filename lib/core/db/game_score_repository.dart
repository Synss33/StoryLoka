import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../db/database_provider.dart';

/// Satu baris riwayat kuis pada tabel `game_scores` (Bagian 5.2).
class GameScoreEntry {
  const GameScoreEntry({
    this.id,
    required this.userId,
    required this.score,
    required this.coins,
    required this.playedAt,
  });

  final int? id;
  final int userId;
  final int score;
  final int coins;

  /// Epoch ms saat ronde selesai.
  final int playedAt;

  Map<String, Object?> toRow() => <String, Object?>{
        if (id != null) 'id': id,
        'user_id': userId,
        'score': score,
        'coins': coins,
        'played_at': playedAt,
      };
}

/// Akses tabel `game_scores` — mini game Book Trivia (F-13 · WF-09).
///
/// Setiap ronde yang selesai menambah satu baris (skor + koin ronde);
/// skor tertinggi = `MAX(score)`, total koin = `SUM(coins)` (dipakai
/// statistik SCR-09).
class GameScoreRepository {
  GameScoreRepository(this._db);

  final Database _db;

  /// Menyimpan hasil satu ronde (TC-28).
  Future<int> save({
    required int userId,
    required int score,
    required int coins,
    required int playedAt,
  }) {
    return _db.insert(
      'game_scores',
      GameScoreEntry(
        userId: userId,
        score: score,
        coins: coins,
        playedAt: playedAt,
      ).toRow(),
    );
  }

  /// Skor tertinggi pengguna; `null` bila belum pernah bermain.
  Future<int?> bestScore(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(score) AS best FROM game_scores WHERE user_id = ?',
      <Object?>[userId],
    );
    return rows.first['best'] as int?;
  }

  /// Jumlah ronde yang pernah dimainkan.
  Future<int> playCount(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM game_scores WHERE user_id = ?',
      <Object?>[userId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Total koin akumulasi (sumber angka "koin" di SCR-09).
  Future<int> totalCoins(int userId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(coins), 0) AS c FROM game_scores WHERE user_id = ?',
      <Object?>[userId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}

final gameScoreRepositoryProvider =
    FutureProvider<GameScoreRepository?>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  if (db == null) return null;
  return GameScoreRepository(db);
});

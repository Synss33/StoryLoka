import 'package:sqflite_sqlcipher/sqflite.dart';

import '../db/settings_repository.dart';
import '../models/book.dart';

/// Ringkasan baca untuk SCR-02 (Reading Summary) dan SCR-15 (target).
///
/// Semua angka dihitung dari tabel lokal; streak = jumlah hari
/// berturut-turut (termasuk hari ini atau kemarin) yang punya sesi baca.
class ReadingStats {
  const ReadingStats({
    required this.readingCount,
    required this.completedCount,
    required this.streakDays,
    required this.monthlyTarget,
    required this.monthlyDone,
    required this.currentlyReading,
  });

  /// Jumlah buku berstatus `reading`.
  final int readingCount;

  /// Jumlah buku berstatus `completed`.
  final int completedCount;

  /// Streak membaca (hari berturut-turut dengan sesi).
  final int streakDays;

  /// Target buku selesai bulan ini (dari `settings.monthly_target`).
  final int monthlyTarget;

  /// Jumlah buku selesai pada bulan berjalan.
  final int monthlyDone;

  /// Buku yang sedang dibaca (terbaru) — kartu Currently Reading.
  final Book? currentlyReading;

  /// 0…1 kemajuan target bulanan (0 bila target 0).
  double get monthlyProgress =>
      monthlyTarget <= 0 ? 0 : (monthlyDone / monthlyTarget).clamp(0.0, 1.0);

  static const ReadingStats empty = ReadingStats(
    readingCount: 0,
    completedCount: 0,
    streakDays: 0,
    monthlyTarget: 5,
    monthlyDone: 0,
    currentlyReading: null,
  );

  /// Menghitung seluruh metrik dari database.
  ///
  /// [now] dapat disuntik untuk pengujian (streak & bulan berjalan).
  static Future<ReadingStats> load(
    Database db,
    int userId, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();

    Future<int> scalar(String sql, List<Object?> args) async {
      final rows = await db.rawQuery(sql, args);
      if (rows.isEmpty || rows.first.values.isEmpty) return 0;
      final value = rows.first.values.first;
      if (value is! num) return 0;
      return value.toInt();
    }

    final readingCount = await scalar(
      "SELECT COUNT(*) FROM books "
      "WHERE user_id = ? AND status = 'reading' AND deleted = 0",
      <Object?>[userId],
    );
    final completedCount = await scalar(
      "SELECT COUNT(*) FROM books "
      "WHERE user_id = ? AND status = 'completed' AND deleted = 0",
      <Object?>[userId],
    );

    // Bulan berjalan (epoch ms): bandingkan finished_at buku.
    final monthStart = DateTime(clock.year, clock.month, 1);
    final monthlyDone = await scalar(
      'SELECT COUNT(*) FROM books '
      'WHERE user_id = ? AND status = \'completed\' AND deleted = 0 '
      'AND finished_at IS NOT NULL AND finished_at >= ?',
      <Object?>[userId, monthStart.millisecondsSinceEpoch],
    );

    final streakDays = await _streakDays(db, userId, clock);

    final settings = await SettingsRepository(db).read(userId);
    final monthlyTarget = settings?.monthlyTarget ?? 5;

    // Currently Reading: buku reading terbaru.
    final rows = await db.query(
      'books',
      where: "user_id = ? AND status = 'reading' AND deleted = 0",
      whereArgs: <Object?>[userId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    final current = rows.isEmpty ? null : Book.fromRow(rows.first);

    return ReadingStats(
      readingCount: readingCount,
      completedCount: completedCount,
      streakDays: streakDays,
      monthlyTarget: monthlyTarget,
      monthlyDone: monthlyDone,
      currentlyReading: current,
    );
  }

  /// Streak = hari berturut-turut yang punya setidaknya satu sesi baca,
  /// dihitung mundur dari hari ini (atau kemarin bila hari ini belum ada
  /// sesi — streak tidak langsung putus sebelum tengah malam).
  static Future<int> _streakDays(Database db, int userId, DateTime clock) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT date(s.start_ts / 1000, \'unixepoch\', \'localtime\') AS d '
      'FROM reading_sessions s '
      'JOIN books b ON s.book_id = b.id '
      'WHERE b.user_id = ? AND b.deleted = 0 '
      'ORDER BY d DESC',
      <Object?>[userId],
    );
    final days =
        rows.map((r) => r['d'] as String?).whereType<String>().toSet();

    DateTime dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
    var cursor = dayOf(clock);
    // Bila hari ini belum ada sesi, mulai cek dari kemarin.
    if (!_has(days, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!_has(days, cursor)) return 0;
    }

    var streak = 0;
    while (_has(days, cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static bool _has(Set<String> days, DateTime day) {
    final iso = day.toIso8601String().split('T').first;
    return days.contains(iso);
  }
}

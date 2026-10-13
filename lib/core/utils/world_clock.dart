/// Konversi zona waktu (F-18, SCR-04): WIB (UTC+7), WITA (UTC+8),
/// WIT (UTC+9), dan London (UTC+0 / UTC+1 mengikuti DST).
///
/// Implementasi murni Dart tanpa paket tambahan agar dapat diuji di host
/// (TC-18) dan bekerja offline. Aturan DST London mengikuti standar Eropa:
/// aktif dari Minggu terakhir Maret pukul 01:00 UTC hingga Minggu terakhir
/// Oktober pukul 01:00 UTC (lokal 02:00 BST).
enum WorldZone {
  wib('WIB', 'Waktu Indonesia Barat', Duration(hours: 7)),
  wita('WITA', 'Waktu Indonesia Tengah', Duration(hours: 8)),
  wit('WIT', 'Waktu Indonesia Timur', Duration(hours: 9)),
  london('London', 'London (GMT/BST)', null);

  const WorldZone(this.code, this.label, this.fixedOffset);

  /// Kode singkat untuk ditampilkan ("WIB", "London", …).
  final String code;

  /// Label lengkap untuk tooltip/keterangan.
  final String label;

  /// Offset tetap dari UTC; `null` untuk zona dengan DST (London).
  final Duration? fixedOffset;
}

abstract final class WorldClock {
  /// Offset London pada waktu [utc]: +1 jam (BST) saat DST, selain itu GMT.
  static Duration londonOffset(DateTime utc) {
    final t = _asUtc(utc);
    final start = _lastSundayUtc(t.year, DateTime.march);
    final end = _lastSundayUtc(t.year, DateTime.october);
    final dst = !t.isBefore(start) && t.isBefore(end);
    return dst ? const Duration(hours: 1) : Duration.zero;
  }

  /// Offset [zone] pada waktu [utc] (London memakai aturan DST).
  static Duration offsetOf(WorldZone zone, DateTime utc) =>
      zone.fixedOffset ?? londonOffset(utc);

  /// Waktu UTC dari waktu lokal [local] di [zone].
  ///
  /// Untuk zona tetap: `local - offset`. Untuk London: offset diuji dengan
  /// menebak BST lebih dulu (cukup akurat untuk jadwal book club).
  static DateTime toUtc(DateTime local, WorldZone zone) {
    final asUtc = _asUtc(local);
    if (zone.fixedOffset != null) return asUtc.subtract(zone.fixedOffset!);
    // Asumsikan BST (UTC+1); bila tebakan itu memang saat DST, sah.
    final guess = asUtc.subtract(const Duration(hours: 1));
    if (londonOffset(guess) == const Duration(hours: 1)) return guess;
    return asUtc;
  }

  /// Waktu lokal di [zone] untuk waktu [utc].
  static DateTime fromUtc(DateTime utc, WorldZone zone) {
    final t = _asUtc(utc);
    return t.add(offsetOf(zone, t));
  }

  /// Mengonversi [reference] (waktu lokal di [from]) ke seluruh zona.
  static Map<WorldZone, DateTime> convertAll(
    DateTime reference, {
    WorldZone from = WorldZone.wib,
  }) {
    final utc = toUtc(reference, from);
    return {
      for (final zone in WorldZone.values) zone: fromUtc(utc, zone),
    };
  }

  /// "HH:mm" dua digit (24 jam) — format tampilan konverter.
  static String formatHm(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// "Sen, 13 Okt 2026" — tanggal ringkas berbahasa Indonesia.
  static String formatTanggal(DateTime time) {
    const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    // DateTime.berdasarkan zona lokal; untuk tampilan cukup pakai weekday.
    final idx = (time.weekday - 1) % 7;
    return '${hari[idx]}, ${time.day} ${bulan[time.month - 1]} ${time.year}';
  }

  static DateTime _asUtc(DateTime time) => DateTime.utc(
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
        time.second,
      );

  /// Minggu terakhir dalam [month] tahun [year], pukul 01:00 UTC
  /// (batas perubahan DST di Britania Raya).
  static DateTime _lastSundayUtc(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    var day = lastDay;
    while (day.weekday != DateTime.sunday) {
      day = day.subtract(const Duration(days: 1));
    }
    return DateTime.utc(year, month, day.day, 1);
  }
}

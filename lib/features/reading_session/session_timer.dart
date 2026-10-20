/// Stopwatch sesi membaca berbasis **timestamp** (F-19, SCR-15).
///
/// Durasi dihitung dari selisih waktu nyata (`now − start_ts − jeda`),
/// bukan penghitung per detik — sehingga tetap akurat saat aplikasi
/// berpindah ke latar belakang (TC-15, ketentuan dosen).
class SessionTimer {
  SessionTimer({required this.startTs, int? now})
      : _pausedTotalMs = 0,
        _pausedAt = null;

  /// Epoch ms saat sesi dimulai (tidak berubah sepanjang sesi).
  final int startTs;

  int _pausedTotalMs;
  int? _pausedAt;

  /// true bila sedang dijeda.
  bool get isPaused => _pausedAt != null;

  /// Menjeda stopwatch pada waktu [now].
  void pause(int now) {
    if (_pausedAt != null) return;
    _pausedAt = now;
  }

  /// Melanjutkan stopwatch; akumulasi jeda ditambahkan.
  void resume(int now) {
    final pausedAt = _pausedAt;
    if (pausedAt == null) return;
    _pausedTotalMs += now - pausedAt;
    _pausedAt = null;
  }

  /// Durasi berjalan (ms) pada waktu [now] — belum dibulatkan.
  int elapsedMs(int now) {
    final end = _pausedAt ?? now;
    final elapsed = end - startTs - _pausedTotalMs;
    return elapsed < 0 ? 0 : elapsed;
  }

  /// Durasi sesi dalam **detik** saat disimpan (TC-15: akurat ±1 dtk).
  int durationSec(int now) => elapsedMs(now) ~/ 1000;

  /// Format tampilan "HH:MM:SS" (angka stopwatch SCR-15).
  static String format(int elapsedMs) {
    final totalSec = elapsedMs ~/ 1000;
    final h = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

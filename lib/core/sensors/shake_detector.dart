import 'dart:math' as math;

/// Satu sampel *user accelerometer* (tanpa gravitasi) beserta timestamp-nya.
///
/// Magnitudo = √(x² + y² + z²) dalam m/s²; [at] memakai timestamp sampel
/// dari platform (bukan `DateTime.now()`) agar deteksi deterministik saat
/// pengujian (keputusan WF-06).
class AccelSample {
  const AccelSample({required this.magnitude, required this.at});

  final double magnitude;
  final DateTime at;

  /// Menghitung magnitudo dari komponen sumbu.
  factory AccelSample.fromAxes(double x, double y, double z, DateTime at) =>
      AccelSample(magnitude: math.sqrt(x * x + y * y + z * z), at: at);
}

/// Detektor *Shake to Discover* — dokumen desain Bagian 4 / workflow 3.6:
/// magnitudo > 12 m/s², **2 guncangan dalam 600 ms**, lalu jeda (debounce)
/// 1,5 dtk sebelum boleh memicu lagi.
///
/// Logika murni tanpa dependensi platform — sensor asli dipasok lewat
/// stream di `sensor_streams.dart`, dan pengujian memberi sampel buatan.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 12,
    this.shakeWindow = const Duration(milliseconds: 600),
    this.debounce = const Duration(milliseconds: 1500),
  });

  /// Ambang magnitudo (m/s²) — gravitasi diam (9,8) sengaja tidak termasuk.
  final double threshold;

  /// Jendela 2 guncangan (600 ms).
  final Duration shakeWindow;

  /// Jeda antar-keluaran (1,5 dtk) agar tidak dobel.
  final Duration debounce;

  final List<DateTime> _peaks = <DateTime>[];
  DateTime? _lastFired;

  /// Memberi satu sampel; bernilai `true` bila shake terpicu.
  ///
  /// Sampel diam/berjalan (di bawah ambang) tidak pernah mengubah puncak
  /// selain membuang puncak lama yang sudah keluar jendela (TC-20).
  bool feed(AccelSample sample) {
    final now = sample.at;

    // Buang puncak yang sudah keluar dari jendela guncangan.
    _peaks.removeWhere((peak) => now.difference(peak) > shakeWindow);

    if (sample.magnitude <= threshold) return false;

    _peaks.add(now);
    if (_peaks.length < 2) return false;

    final lastFired = _lastFired;
    if (lastFired != null && now.difference(lastFired) < debounce) {
      return false;
    }

    _peaks.clear();
    _lastFired = now;
    return true;
  }
}

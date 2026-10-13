import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:light_sensor/light_sensor.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'shake_detector.dart';

/// Stream sampel *user accelerometer* (tanpa gravitasi) — sensor 2 (shake).
///
/// Hanya Android/iOS yang memiliki sensor (workflow 3.6); platform lain
/// (mis. host pengembangan) memakai stream kosong sehingga tidak pernah
/// memanggil channel platform. Kegagalan channel ditelan agar fitur shake
/// cukup diam bila sensor tidak tersedia.
final accelSampleStreamProvider = Provider<Stream<AccelSample>>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const Stream<AccelSample>.empty();
  }
  try {
    return userAccelerometerEventStream()
        .map(
          (event) =>
              AccelSample.fromAxes(event.x, event.y, event.z, event.timestamp),
        )
        .handleError((Object _, StackTrace _) {});
  } catch (_) {
    return const Stream<AccelSample>.empty();
  }
});

/// Stream lux sensor cahaya — sensor 1 (auto-theme).
///
/// Sensor cahaya hanya ada di Android (dokumen desain Bagian 4; iOS tidak
/// punya API publik → ikuti tema sistem). Bila tidak tersedia atau channel
/// error, stream tetap diam tanpa menggagalkan provider.
final luxStreamProvider = Provider<Stream<int>>((ref) {
  if (!Platform.isAndroid) return const Stream<int>.empty();
  try {
    return LightSensor.luxStream().handleError((Object _, StackTrace _) {});
  } catch (_) {
    return const Stream<int>.empty();
  }
});

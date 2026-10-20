import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Akses lokasi perangkat yang dapat disuntikkan untuk pengujian
/// (F-16 / WF-06 — layar SCR-04: izin runtime, GPS mati, buka
/// pengaturan sistem).
abstract class LocationService {
  /// Layanan lokasi perangkat aktif? (GPS menyala)
  Future<bool> isServiceEnabled();

  Future<LocationPermission> checkPermission();

  /// Permintaan izin runtime (memicu dialog sistem).
  Future<LocationPermission> requestPermission();

  Future<LatLng> getCurrentPosition();

  /// Membuka halaman izin aplikasi di pengaturan sistem.
  Future<bool> openAppSettings();

  /// Membuka pengaturan lokasi/grup sistem.
  Future<bool> openLocationSettings();
}

/// Implementasi asli berbasis Geolocator.
class GeolocatorLocationService implements LocationService {
  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LatLng> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Layanan lokasi aktif (di-override dengan tiruan saat pengujian — TC-22).
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

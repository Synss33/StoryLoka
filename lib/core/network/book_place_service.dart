import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tempat terkait bacaan di sekitar pengguna — toko buku & perpustakaan
/// dalam radius 3 km (dokumen desain Bagian 6 SCR-04).
class BookPlace {
  const BookPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.isLibrary,
    this.openingHours,
  });

  final String name;
  final double lat;
  final double lon;
  final bool isLibrary;

  /// Tag `opening_hours` mentah (bila tersedia).
  final String? openingHours;

  /// Jarak lurus (Haversine) ke [from] dalam meter.
  ///
  /// Dihitung lokal, bukan `Geolocator.distanceBetween`, agar aman di
  /// pengujian tanpa panggilan platform.
  double distanceFrom(LatLng from) => haversineMeters(from, LatLng(lat, lon));

  /// `true` = buka, `false` = tutup, `null` = jam tidak terbaca.
  ///
  /// Hanya membaca rentang `HH:MM-HH:MM` (harian); rentang berbasis hari
  /// (`Mo-Fr …`) ikut diperiksa sebagai jam berlaku umum.
  bool? isOpenNow(DateTime local) {
    final rules = openingHours;
    if (rules == null || rules.trim().isEmpty) return null;

    final ranges = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})')
        .allMatches(rules)
        .toList();
    if (ranges.isEmpty) return null;

    final now = local.hour * 60 + local.minute;
    for (final range in ranges) {
      final start = int.parse(range.group(1)!) * 60 + int.parse(range.group(2)!);
      final end = int.parse(range.group(3)!) * 60 + int.parse(range.group(4)!);
      if (now >= start && now < end) return true;
    }
    return false;
  }
}

/// Jarak Haversine dalam meter (bumi = 6.371 km).
double haversineMeters(LatLng from, LatLng to) {
  const earthRadius = 6371000.0;
  final dLat = _rad(to.latitude - from.latitude);
  final dLon = _rad(to.longitude - from.longitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(from.latitude)) *
          math.cos(_rad(to.latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double degrees) => degrees * math.pi / 180;

/// Sumber data tempat (dapat disuntikkan untuk pengujian).
abstract class BookPlaceService {
  /// Mengambil toko buku/perpustakaan dalam [radiusMeters] dari [center].
  Future<PlacesResult> nearby(
    LatLng center, {
    double radiusMeters = 3000,
  });
}

/// Hasil pencarian tempat: daftar + asal data (server / cache lokal).
class PlacesResult {
  const PlacesResult({
    required this.places,
    required this.fromCache,
    this.savedAtMs,
  });

  final List<BookPlace> places;

  /// `true` bila semua endpoint gagal dan data berasal dari cache lokal
  /// (label "data offline" di SCR-04 — mitigasi workflow Bagian 5).
  final bool fromCache;

  /// Epoch ms cache dibuat (hanya saat [fromCache]).
  final int? savedAtMs;
}

/// Kegagalan seluruh endpoint Overpass **dan** cache kosong/tidak terbaca.
class PlacesUnavailableException implements Exception {
  const PlacesUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'PlacesUnavailableException: $cause';
}

/// Overpass API (OpenStreetMap) — jaringan diperlukan; kegagalan/melewati
/// timeout dilempar agar layar menampilkan state offline (SCR-13).
///
/// Ketahanan (perbaikan 2026-10-20): endpoint **cadangan** (mirror Kumi)
/// dicoba bila endpoint utama gagal; bila keduanya gagal, hasil terakhir
/// yang sukses dibaca dari **cache file** (`places_cache.json`) dan
/// ditandai [PlacesResult.fromCache] untuk label "data offline".
class OverpassBookPlaceService implements BookPlaceService {
  OverpassBookPlaceService({http.Client? client})
      : _client = client ?? http.Client();

  /// Endpoint utama lalu mirror publik Overpass.
  static final List<Uri> _endpoints = <Uri>[
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
  ];

  static const String _cacheFileName = 'places_cache.json';

  final http.Client _client;

  @override
  Future<PlacesResult> nearby(
    LatLng center, {
    double radiusMeters = 3000,
  }) async {
    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final places = await _query(endpoint, center, radiusMeters);
        await _writeCache(places, center);
        return PlacesResult(places: places, fromCache: false);
      } catch (e) {
        lastError = e;
      }
    }
    final cached = await _readCache();
    if (cached != null) return cached;
    throw PlacesUnavailableException(lastError ?? 'Overpass tidak tersedia');
  }

  Future<List<BookPlace>> _query(
    Uri endpoint,
    LatLng center,
    double radiusMeters,
  ) async {
    final radius = radiusMeters.round();
    final around = '$radius,${center.latitude},${center.longitude}';
    final query = '''
[out:json][timeout:25];
(
  node["shop"="books"](around:$around);
  way["shop"="books"](around:$around);
  node["amenity"="library"](around:$around);
  way["amenity"="library"](around:$around);
);
out center 60;
''';

    final response = await _client
        .post(endpoint, body: query)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('Overpass ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>? ?? const [];
    final places = <BookPlace>[];

    for (final raw in elements) {
      final element = raw as Map<String, dynamic>;
      final tags = element['tags'] as Map<String, dynamic>? ?? const {};
      // Way hanya punya koordinat di `center`; node menyimpannya langsung.
      final position = element['center'] as Map<String, dynamic>? ?? element;
      final lat = (position['lat'] as num?)?.toDouble();
      final lon = (position['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final isLibrary = tags['amenity'] == 'library';
      final name = tags['name'] as String? ??
          (isLibrary ? 'Perpustakaan' : 'Toko Buku');
      places.add(
        BookPlace(
          name: name,
          lat: lat,
          lon: lon,
          isLibrary: isLibrary,
          openingHours: tags['opening_hours'] as String?,
        ),
      );
    }

    places.sort(
      (a, b) => a.distanceFrom(center).compareTo(b.distanceFrom(center)),
    );
    return places;
  }

  /// Menyimpan hasil sukses ke cache (best-effort — gagal diabaikan).
  Future<void> _writeCache(List<BookPlace> places, LatLng center) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final payload = <String, Object?>{
        'saved_at': DateTime.now().millisecondsSinceEpoch,
        'lat': center.latitude,
        'lon': center.longitude,
        'places': places
            .map((p) => <String, Object?>{
                  'name': p.name,
                  'lat': p.lat,
                  'lon': p.lon,
                  'is_library': p.isLibrary,
                  'opening_hours': p.openingHours,
                })
            .toList(),
      };
      await File(p.join(dir.path, _cacheFileName))
          .writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Perangkat tanpa penyimpanan/izin → cache opsional.
    }
  }

  /// Membaca cache bila ada (null bila tidak ada/rusak).
  Future<PlacesResult?> _readCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _cacheFileName));
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final savedAt = (decoded['saved_at'] as num?)?.toInt();
      final rawPlaces = decoded['places'];
      if (rawPlaces is! List) return null;
      final places = <BookPlace>[];
      for (final raw in rawPlaces) {
        if (raw is! Map<String, dynamic>) continue;
        final lat = (raw['lat'] as num?)?.toDouble();
        final lon = (raw['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) continue;
        places.add(
          BookPlace(
            name: raw['name'] as String? ?? 'Tempat',
            lat: lat,
            lon: lon,
            isLibrary: raw['is_library'] as bool? ?? false,
            openingHours: raw['opening_hours'] as String?,
          ),
        );
      }
      if (places.isEmpty) return null;
      return PlacesResult(places: places, fromCache: true, savedAtMs: savedAt);
    } catch (_) {
      return null;
    }
  }
}

/// Sumber tempat terdekat (di-override dengan tiruan saat pengujian).
final bookPlaceServiceProvider = Provider<BookPlaceService>((ref) {
  return OverpassBookPlaceService();
});

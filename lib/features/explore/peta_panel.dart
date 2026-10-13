import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/location/location_service.dart';
import '../../core/network/book_place_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/storyloka_card.dart';

/// Segmen **Peta (LBS)** SCR-04 — F-16 / WF-06 (dokumen desain Bagian 6,
/// workflow 5.10): peta OSM + marker toko buku/perpustakaan radius 3 km.
///
/// State yang wajib: izin ditolak (kartu ajakan + **Buka Pengaturan**),
/// GPS mati, memuat, offline/error, dan siap.
class PetaPanel extends ConsumerStatefulWidget {
  const PetaPanel({super.key});

  @override
  ConsumerState<PetaPanel> createState() => _PetaPanelState();
}

enum _PetaView { checking, gpsOff, denied, deniedForever, loading, ready, error }

class _PetaPanelState extends ConsumerState<PetaPanel> {
  _PetaView _view = _PetaView.checking;
  bool _busy = false;
  LatLng? _here;
  List<BookPlace> _places = const <BookPlace>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  /// Cek layanan lokasi + izin runtime; bila beres → muat tempat terdekat.
  Future<void> _locate() async {
    setState(() => _view = _PetaView.checking);
    final service = ref.read(locationServiceProvider);
    try {
      if (!await service.isServiceEnabled()) {
        if (mounted) setState(() => _view = _PetaView.gpsOff);
        return;
      }
      final permission = await service.checkPermission();
      if (!mounted) return;
      switch (permission) {
        case LocationPermission.denied:
          setState(() => _view = _PetaView.denied);
        case LocationPermission.deniedForever:
          setState(() => _view = _PetaView.deniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          await _loadPlaces();
      }
    } catch (_) {
      if (mounted) setState(() => _view = _PetaView.error);
    }
  }

  /// Meminta izin runtime (dialog sistem) lalu memuat tempat bila diberi.
  Future<void> _requestPermission() async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(locationServiceProvider);
    try {
      final permission = await service.requestPermission();
      if (!mounted) return;
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _loadPlaces();
      } else {
        setState(() {
          _view = permission == LocationPermission.deniedForever
              ? _PetaView.deniedForever
              : _PetaView.denied;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _view = _PetaView.error;
          _busy = false;
        });
      }
    }
  }

  /// Mengambil posisi lalu tempat terdekat (radius 3 km).
  Future<void> _loadPlaces() async {
    setState(() {
      _view = _PetaView.loading;
      _busy = false;
    });
    final location = ref.read(locationServiceProvider);
    final places = ref.read(bookPlaceServiceProvider);
    try {
      final here = await location.getCurrentPosition();
      final found = await places.nearby(here);
      if (!mounted) return;
      setState(() {
        _here = here;
        _places = found;
        _view = _PetaView.ready;
      });
    } catch (_) {
      // Offline / Overpass gagal → state error (SCR-13).
      if (mounted) setState(() => _view = _PetaView.error);
    }
  }

  /// Tombol **Rute** → aplikasi peta eksternal; gagal/offline → koordinat.
  Future<void> _openRoute(BookPlace place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.lat},${place.lon}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Buka peta manual: ${place.lat}, ${place.lon}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return switch (_view) {
      _PetaView.checking => const _CenterNote(
          icon: Icons.my_location_outlined,
          message: 'Memeriksa lokasi…',
        ),
      _PetaView.loading => const _CenterNote(
          icon: Icons.hourglass_empty_rounded,
          message: 'Mencari tempat di sekitarmu…',
        ),
      _PetaView.gpsOff => StorylokaCard(
          child: Column(
            children: [
              Icon(Icons.location_off_outlined, size: 40, color: p.danger500),
              const SizedBox(height: AppSpacing.cardGap),
              Text(
                'Lokasi Perangkat Nonaktif',
                style: AppTypography.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Nyalakan GPS/Lokasi agar peta toko buku dan perpustakaan '
                'terdekat dapat dimuat.',
                style: AppTypography.body2.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.cardGap),
              PrimaryButton(
                key: const ValueKey<String>('open-location-settings'),
                label: 'Buka Pengaturan Lokasi',
                icon: Icons.settings_outlined,
                onPressed: () =>
                    ref.read(locationServiceProvider).openLocationSettings(),
              ),
            ],
          ),
        ),
      _PetaView.denied || _PetaView.deniedForever => StorylokaCard(
          key: const ValueKey<String>('location-permission-card'),
          child: Column(
            children: [
              Icon(Icons.location_on_outlined, size: 40, color: p.primary500),
              const SizedBox(height: AppSpacing.cardGap),
              Text(
                'Izin Lokasi Diperlukan',
                style: AppTypography.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Storyloka membutuhkan lokasimu untuk menampilkan toko buku '
                'dan perpustakaan dalam radius 3 km beserta jaraknya.',
                style: AppTypography.body2.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.cardGap),
              if (_view == _PetaView.denied) ...[
                PrimaryButton(
                  key: const ValueKey<String>('request-location'),
                  label: 'Izinkan Lokasi',
                  icon: Icons.check_circle_outline,
                  loading: _busy,
                  onPressed: _requestPermission,
                ),
                const SizedBox(height: AppSpacing.grid),
              ],
              OutlinedButton(
                key: const ValueKey<String>('open-app-settings'),
                onPressed: () =>
                    ref.read(locationServiceProvider).openAppSettings(),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        ),
      _PetaView.error => StorylokaCard(
          child: Column(
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: p.danger500),
              const SizedBox(height: AppSpacing.cardGap),
              Text(
                'Gagal Memuat Peta',
                style: AppTypography.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                'Koneksi terputus — periksa jaringan lalu coba lagi. '
                'Fitur lokal tetap berfungsi.',
                style: AppTypography.body2.copyWith(color: p.neutral500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.cardGap),
              PrimaryButton(
                key: const ValueKey<String>('retry-places'),
                label: 'Coba Lagi',
                onPressed: _locate,
              ),
            ],
          ),
        ),
      _PetaView.ready => _buildReady(p),
    };
  }

  /// Peta OSM + daftar kartu tempat (nama, jarak, buka/tutup, Rute).
  Widget _buildReady(AppPalette p) {
    final here = _here;
    if (here == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadius.mediumAll,
          child: SizedBox(
            height: 240,
            child: FlutterMap(
              options: MapOptions(initialCenter: here, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.storyloka.app',
                ),
                MarkerLayer(
                  markers: [
                    for (final place in _places)
                      Marker(
                        point: LatLng(place.lat, place.lon),
                        width: 32,
                        height: 32,
                        child: Icon(
                          place.isLibrary
                              ? Icons.local_library_outlined
                              : Icons.storefront_outlined,
                          color: p.primary500,
                          size: 28,
                        ),
                      ),
                    Marker(
                      point: here,
                      width: 28,
                      height: 28,
                      child: Icon(Icons.my_location, color: p.danger500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        if (_places.isEmpty)
          Text(
            'Belum ada toko buku/perpustakaan dalam radius 3 km.',
            style: AppTypography.body2.copyWith(color: p.neutral500),
            textAlign: TextAlign.center,
          )
        else
          for (var i = 0; i < _places.length; i++) ...[
            _PlaceCard(
              place: _places[i],
              from: here,
              routeKey: ValueKey<String>('route-$i'),
              onRoute: () => _openRoute(_places[i]),
            ),
            if (i != _places.length - 1)
              const SizedBox(height: AppSpacing.cardGap),
          ],
        const SizedBox(height: AppSpacing.cardGap),
      ],
    );
  }
}

/// Kartu satu tempat: nama · jarak · status buka/tutup · tombol Rute.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.from,
    required this.routeKey,
    required this.onRoute,
  });

  final BookPlace place;
  final LatLng from;
  final Key routeKey;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final meters = place.distanceFrom(from);
    final open = place.isOpenNow(DateTime.now());

    return StorylokaCard(
      child: Row(
        children: [
          Icon(
            place.isLibrary
                ? Icons.local_library_outlined
                : Icons.storefront_outlined,
            color: p.primary500,
          ),
          const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: AppTypography.body1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  '${formatDistance(meters)} · '
                  '${open == null ? 'Jam tidak diketahui' : (open ? 'Buka' : 'Tutup')}',
                  style: AppTypography.caption.copyWith(color: p.neutral500),
                ),
              ],
            ),
          ),
          OutlinedButton(
            key: routeKey,
            onPressed: onRoute,
            child: const Text('Rute'),
          ),
        ],
      ),
    );
  }
}

/// Jarak ramah: 800 m / 1,5 km (laut desain SCR-04).
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$km km';
}

/// Pusat sederhana untuk state memuat/memeriksa.
class _CenterNote extends StatelessWidget {
  const _CenterNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.screenMargin),
          Icon(icon, size: 40, color: p.neutral500),
          const SizedBox(height: AppSpacing.cardGap),
          Text(
            message,
            style: AppTypography.body2.copyWith(color: p.neutral500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

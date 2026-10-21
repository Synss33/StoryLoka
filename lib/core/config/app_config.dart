/// Konfigurasi build aplikasi — **satu-satunya tempat** yang perlu diubah
/// untuk mengarahkan aplikasi ke backend lain.
///
/// ```sh
/// # emulator Android (default)
/// flutter run
/// # atau tentukan saat build tanpa mengubah file:
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000
/// ```
///
/// Perangkat yang meng-clone repo: ganti [apiBaseUrl] di bawah (atau
/// build dengan `--dart-define`) — tidak ada URL lain di kode.
abstract final class AppConfig {
  /// Alamat backend Storyloka. Nilai bawaan: loopback emulator Android
  /// (keputusan 4); HP fisik: `http://<ip-komputer>:3000`; produksi:
  /// `https://<domain-backend>`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}

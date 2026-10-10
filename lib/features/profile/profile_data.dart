import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import '../../core/db/settings_repository.dart';
import '../../core/models/app_settings.dart';
import '../auth/auth_controller.dart';
import '../auth/biometric_service.dart';
import '../auth/session_service.dart';
import '../auth/user_repository.dart';
import 'profile_stats.dart';

/// Seluruh data yang ditampilkan SCR-09 dalam satu async provider.
///
/// Setiap aksi pengaturan (biometrik, pengingat, sinkronisasi, edit profil)
/// cukup memanggil `ref.invalidate(profileDataProvider)` untuk memuat ulang.
class ProfileData {
  const ProfileData({
    required this.user,
    required this.settings,
    required this.stats,
    required this.sessionExpiry,
    required this.biometricSupported,
  });

  final UserRecord? user;
  final AppSettings? settings;
  final ProfileStats stats;

  /// `SessionInfo.expiresAt` (epoch ms) — tampilan "Sesi berlaku hingga".
  final int? sessionExpiry;

  /// Perangkat tanpa biometrik → opsi disembunyikan (deskripsi §5.1).
  final bool biometricSupported;
}

final profileDataProvider = FutureProvider.autoDispose<ProfileData>((ref) async {
  final userId = ref.watch(authControllerProvider).userId;
  if (userId == null) {
    throw const AuthException('Tidak ada sesi aktif.');
  }

  final users = await ref.watch(userRepositoryProvider.future);
  final settings = await ref.watch(settingsRepositoryProvider.future);
  final db = await ref.watch(databaseProvider.future);
  final session = await ref.watch(sessionServiceProvider).rawSession();
  final biometricSupported =
      await ref.watch(biometricServiceProvider).isSupported();

  return ProfileData(
    user: await users.byId(userId),
    settings: settings == null ? null : await settings.read(userId),
    stats: db == null
        ? const ProfileStats(
            booksRead: 0,
            hoursRead: 0,
            certificates: 0,
            coins: 0,
          )
        : await ProfileStats.load(db, userId),
    sessionExpiry: session?.expiresAt,
    biometricSupported: biometricSupported,
  );
});

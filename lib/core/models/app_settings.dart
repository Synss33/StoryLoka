/// Baris pengaturan pengguna (tabel `settings`).
///
/// `updated_at` (skema v2) membuat konflik pengaturan dapat diselesaikan
/// dengan aturan *last-write-wins* yang sama seperti tabel lain.
class AppSettings {
  const AppSettings({
    required this.userId,
    this.biometricEnabled = false,
    this.reminderOn = true,
    this.reminderTime = '20:00',
    this.themeMode = 'auto',
    this.streakNotify = true,
    this.monthlyTarget = 5,
    this.lastSync,
    required this.updatedAt,
  });

  final int userId;
  final bool biometricEnabled;
  final bool reminderOn;
  final String reminderTime;

  /// 'auto' / 'light' / 'dark' (CHECK di skema).
  final String themeMode;

  /// Notifikasi target & streak (skema v3 — SCR-09).
  final bool streakNotify;
  final int monthlyTarget;
  final int? lastSync;
  final int updatedAt;

  static AppSettings fromRow(Map<String, Object?> row) => AppSettings(
        userId: row['user_id'] as int,
        biometricEnabled: row['biometric_enabled'] == 1,
        reminderOn: row['reminder_on'] == 1,
        reminderTime: row['reminder_time'] as String? ?? '20:00',
        themeMode: row['theme_mode'] as String? ?? 'auto',
        streakNotify: row['streak_notify'] == null || row['streak_notify'] == 1,
        monthlyTarget: row['monthly_target'] as int? ?? 5,
        lastSync: row['last_sync'] as int?,
        updatedAt: row['updated_at'] as int? ?? 0,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'user_id': userId,
        'biometric_enabled': biometricEnabled ? 1 : 0,
        'reminder_on': reminderOn ? 1 : 0,
        'reminder_time': reminderTime,
        'theme_mode': themeMode,
        'streak_notify': streakNotify ? 1 : 0,
        'monthly_target': monthlyTarget,
        'last_sync': lastSync,
        'updated_at': updatedAt,
      };

  Map<String, Object?> toRow() => <String, Object?>{
        'user_id': userId,
        'biometric_enabled': biometricEnabled ? 1 : 0,
        'reminder_on': reminderOn ? 1 : 0,
        'reminder_time': reminderTime,
        'theme_mode': themeMode,
        'streak_notify': streakNotify ? 1 : 0,
        'monthly_target': monthlyTarget,
        'last_sync': lastSync,
        'updated_at': updatedAt,
      };
}

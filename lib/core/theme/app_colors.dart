import 'package:flutter/material.dart';

/// Design token warna Storyloka — dokumen desain Bagian 1.1 (Palet Indigo/Slate).
///
/// SEMUA nilai HEX aplikasi ada di file ini. Widget/layar tidak boleh
/// menulis warna literal; ambil melalui [AppColors.of] agar otomatis
/// mengikuti mode terang/gelap.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.primary500,
    required this.primary600,
    required this.primary50,
    required this.secondary500,
    required this.bg,
    required this.surface,
    required this.neutral100,
    required this.neutral200,
    required this.neutral500,
    required this.textPrimary,
    required this.success500,
    required this.warning500,
    required this.danger500,
    required this.onPrimary,
    required this.cardShadow,
  });

  final Brightness brightness;

  /// Brand, tombol utama, tab aktif.
  final Color primary500;

  /// Pressed/hover; teks atau tombol kecil di atas putih.
  final Color primary600;

  /// Latar kartu aktif / highlight.
  final Color primary50;

  /// Aksen AI/LLM, blockchain, badge.
  final Color secondary500;

  /// Latar layar.
  final Color bg;

  /// Kartu, bottom sheet, navbar.
  final Color surface;

  /// Divider, bubble AI, input terisi.
  final Color neutral100;

  /// Border, dasar shimmer.
  final Color neutral200;

  /// Teks sekunder, placeholder, ikon non-aktif.
  final Color neutral500;

  /// Teks utama.
  final Color textPrimary;

  /// Selesai, blockchain valid.
  final Color success500;

  /// Peringatan, wishlist, pending.
  final Color warning500;

  /// Error, hapus, logout.
  final Color danger500;

  /// Teks di atas [primary500]; dipilih agar kontras tetap ≥ 4,5:1
  /// (terang: putih di atas indigo; gelap: teks gelap di atas indigo terang).
  final Color onPrimary;

  /// Bayangan kartu mode terang `0 2 8 rgba(15,23,42,0.06)`.
  /// Mode gelap tidak memakai bayangan (memakai border [neutral200]).
  final Color cardShadow;
}

abstract final class AppColors {
  /// Palet mode Terang (Bagian 1.1 kolom Light).
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary500: Color(0xFF6366F1),
    primary600: Color(0xFF4F46E5),
    primary50: Color(0xFFEEF2FF),
    secondary500: Color(0xFF8B5CF6),
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    neutral100: Color(0xFFF1F5F9),
    neutral200: Color(0xFFE2E8F0),
    neutral500: Color(0xFF64748B),
    textPrimary: Color(0xFF0F172A),
    success500: Color(0xFF10B981),
    warning500: Color(0xFFF59E0B),
    danger500: Color(0xFFEF4444),
    onPrimary: Color(0xFFFFFFFF),
    cardShadow: Color(0x0F0F172A),
  );

  /// Palet mode Gelap (Bagian 1.1 kolom Dark).
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary500: Color(0xFF818CF8),
    primary600: Color(0xFF6366F1),
    primary50: Color(0xFF1E1B4B),
    secondary500: Color(0xFFA78BFA),
    bg: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    neutral100: Color(0xFF334155),
    neutral200: Color(0xFF475569),
    neutral500: Color(0xFF94A3B8),
    textPrimary: Color(0xFFF1F5F9),
    success500: Color(0xFF34D399),
    warning500: Color(0xFFFBBF24),
    danger500: Color(0xFFF87171),
    onPrimary: Color(0xFF0F172A),
    cardShadow: Color(0x00000000),
  );

  /// Palet aktif sesuai brightness tema yang sedang dipakai.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

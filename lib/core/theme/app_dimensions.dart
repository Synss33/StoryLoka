import 'package:flutter/material.dart';

/// Design token spacing, radius, elevasi, dan ukuran tetap —
/// dokumen desain Bagian 1.3 dan Master Layout Bagian 2.
abstract final class AppSpacing {
  /// Grid dasar 8dp.
  static const double grid = 8;

  /// Mikro grid 4dp.
  static const double micro = 4;

  /// Jarak antar kartu 12dp.
  static const double cardGap = 12;

  /// Margin/padding tepi layar 16dp.
  static const double screenMargin = 16;

  /// Padding dalam kartu 16dp.
  static const double cardPadding = 16;

  /// Target sentuh minimum 48×48dp.
  static const double touchTarget = 48;
}

/// Radius sudut (Bagian 1.3).
abstract final class AppRadius {
  /// Badge, tombol kecil.
  static const double small = 8;

  /// Kartu, input, tombol.
  static const double medium = 12;

  /// Bottom sheet.
  static const double large = 20;

  /// Pill/badge penuh.
  static const double pill = 999;

  static final BorderRadius smallAll = BorderRadius.circular(small);
  static final BorderRadius mediumAll = BorderRadius.circular(medium);
  static final BorderRadius largeAll = BorderRadius.circular(large);
  static final BorderRadius pillAll = BorderRadius.circular(pill);
}

/// Ukuran tinggi/lebar komponen tetap (Master Layout & Bagian 1.3/1.4).
abstract final class AppLayout {
  /// Zona 1: Top Bar 56dp.
  static const double topBarHeight = 56;

  /// Zona 4: Bottom Nav 64dp (belum termasuk safe area).
  static const double bottomNavHeight = 64;

  /// Zona 3: FAB 56dp (hanya SCR-03).
  static const double fabSize = 56;

  /// Rasio cover buku 2:3 (lebar / tinggi).
  static const double bookCoverRatio = 2 / 3;

  /// Tinggi tombol Primary/Secondary 48dp.
  static const double buttonHeight = 48;

  /// Tinggi foto profil SCR-09.
  static const double avatarLarge = 72;

  /// Elevasi kartu mode terang: `0 2 8 rgba(15,23,42,0.06)`
  /// (warna bayangan diambil dari token; mode gelap tanpa bayangan).
  static const Offset cardShadowOffset = Offset(0, 2);
  static const double cardShadowBlur = 8;

  /// Opasitas state disabled (Bagian 1.4).
  static const double disabledOpacity = 0.4;

  /// Ketebalan ring fokus (Bagian 1.4).
  static const double focusRingWidth = 2;

  /// Durasi siklus shimmer skeleton SCR-11 (1,2 detik).
  static const Duration shimmerDuration = Duration(milliseconds: 1200);
}

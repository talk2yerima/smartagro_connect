import 'package:flutter/material.dart';

/// Premium agricultural palette — light-sunlight legible, dark-room safe.
abstract final class AppColors {
  // ─── Brand Greens ───────────────────────────────
  static const deepGreen   = Color(0xFF1B5E20);
  static const emerald     = Color(0xFF2E7D32);   // mid-green (keep name)
  static const freshGreen  = Color(0xFF4CAF50);
  static const mintGreen   = Color(0xFF00C853);   // price-up
  static const lightGreen  = Color(0xFF81C784);

  // ─── Accents ────────────────────────────────────
  static const golden      = Color(0xFFF9A825);
  static const warmOrange  = Color(0xFFFB8C00);
  static const amber       = Color(0xFFFF8F00);

  // ─── Semantic ───────────────────────────────────
  static const success     = Color(0xFF2E7D32);
  static const errorRed    = Color(0xFFC62828);
  static const warningOrange = Color(0xFFE65100);
  static const infoBlue    = Color(0xFF0277BD);

  // ─── Light Surfaces ─────────────────────────────
  static const softWhite   = Color(0xFFF8FAF5);   // page bg
  static const surfaceLight= Color(0xFFF0F4EE);
  static const cardLight   = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE2EAE0);

  // ─── Light Text ─────────────────────────────────
  static const charcoal    = Color(0xFF1F2937);   // primary text
  static const gray        = Color(0xFF6B7280);   // muted
  static const silver      = Color(0xFF9CA3AF);

  // ─── Dark Surfaces ──────────────────────────────
  static const darkBg      = Color(0xFF0F1A0F);
  static const darkSurface = Color(0xFF172517);
  static const cardDark    = Color(0xFF1E2E1E);   // main dark card
  static const darkBorder  = Color(0xFF2E3C2E);

  // ─── Dark Text ──────────────────────────────────
  static const darkTextPrimary   = Color(0xFFE0F0E0);
  static const darkTextSecondary = Color(0xFFA0B8A0);

  // ─── Gradients ──────────────────────────────────
  static const gradientGreen = LinearGradient(
    colors: [deepGreen, emerald],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientAmber = LinearGradient(
    colors: [amber, warmOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Helpers ────────────────────────────────────
  static Color card(bool isDark)    => isDark ? cardDark   : cardLight;
  static Color border_(bool isDark) => isDark ? darkBorder : borderLight;
  static Color surface(bool isDark) => isDark ? darkSurface: surfaceLight;
  static Color text(bool isDark)    => isDark ? darkTextPrimary   : charcoal;
  static Color subText(bool isDark) => isDark ? darkTextSecondary : gray;
  static Color bg(bool isDark)      => isDark ? darkBg : softWhite;
}

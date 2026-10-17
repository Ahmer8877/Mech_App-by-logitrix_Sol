import 'package:flutter/material.dart';

/// Central color tokens — mirrors the CSS variables used in the
/// mechx_ui_kit_v2.html reference so Flutter output stays visually
/// consistent with the design file.
class AppColors {
  AppColors._();

  // ---- Light theme ----
  static const lightBg = Color(0xFFF5F4EF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFEDEBE2);
  static const lightSurface3 = Color(0xFFE3E0D3);
  static const lightText = Color(0xFF161A19);
  static const lightTextSecondary = Color(0xFF5B6764);
  static const lightTextMuted = Color(0xFF8B968F);
  static const lightBorder = Color(0x1A141E1C); // ~10% black
  static const lightBorderStrong = Color(0x2E141E1C); // ~18% black

  // ---- Dark theme ----
  static const darkBg = Color(0xFF10161A);
  static const darkSurface = Color(0xFF1A2226);
  static const darkSurface2 = Color(0xFF212B2F);
  static const darkSurface3 = Color(0xFF2A3539);
  static const darkText = Color(0xFFEEF1EC);
  static const darkTextSecondary = Color(0xFF9DACA6);
  static const darkTextMuted = Color(0xFF69766F);
  static const darkBorder = Color(0x17F0F5F0); // ~9% white
  static const darkBorderStrong = Color(0x29F0F5F0); // ~16% white

  // ---- Brand (same hue family, brighter in dark mode) ----
  static const primaryLight = Color(0xFF145C5C); // Torque Teal
  static const primaryStrongLight = Color(0xFF0E4747);
  static const onPrimaryLight = Color(0xFFF5F4EF);

  static const primaryDark = Color(0xFF3AA89C);
  static const primaryStrongDark = Color(0xFF57C4B6);
  static const onPrimaryDark = Color(0xFF08201D);

  static const accentLight = Color(0xFFFF9F1C); // Spark Amber
  static const onAccentLight = Color(0xFF1A1200);
  static const accentDark = Color(0xFFFFB74D);
  static const onAccentDark = Color(0xFF1A1200);

  static const danger = Color(0xFFE14B3B);
  static const dangerDark = Color(0xFFFF6B5B);
  static const success = Color(0xFF2E9B5C);
  static const successDark = Color(0xFF4FC585);
}

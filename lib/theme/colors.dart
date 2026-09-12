import 'package:flutter/material.dart';

class PaceColors {
  // Brand Design Tokens
  static const Color purple = Color(0xFF4B1D8F);
  static const Color purpleLight = Color(0xFFF4F0FF);
  static const Color purpleGlow = Color(0xFF9155FD);
  static const Color green = Color(0xFF2CB34A);
  static const Color greenLight = Color(0xFFE9F7EF);
  static const Color emerald = Color(0xFF10B981);
  static const Color sapphire = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFE11D48);
  static const Color redLight = Color(0xFFFFF1F2);
  
  // Surface Colors (Light) - Exact WispPortal Tokens
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF111827);
  static const Color border = Color(0xFFE5E7EB);
  static const Color bgSubtle = Color(0xFFF9FAFB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2CB34A);
  static const Color error = Color(0xFFE11D48);
  static const Color warning = Color(0xFFF59E0B);

  // Surface Colors (Dark) - Exact WispPortal Tokens
  static const Color purpleDark = Color(0xFF5B2DA0);
  static const Color purpleLightDark = Color(0xFF1E1830);
  static const Color greenDark = Color(0xFF4ADE80);
  static const Color greenLightDark = Color(0xFF1A2E22);
  static const Color backgroundDark = Color(0xFF0B0E14);
  static const Color foregroundDark = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFF1F2937);
  static const Color bgSubtleDark = Color(0xFF161B22);
  static const Color cardBgDark = Color(0xFF111827);
  static const Color redDark = Color(0xFFFB7185);
  static const Color redLightDark = Color(0xFF2D161B);

  // Admin Palette (Light)
  static const Color adminLabel = Color(0xFF4B5563);
  static const Color adminValue = Color(0xFF111827);
  static const Color adminDim = Color(0xFF9CA3AF);

  // Admin Palette (Dark)
  static const Color adminLabelDark = Color(0xFF9CA3AF);
  static const Color adminValueDark = Color(0xFFF3F4F6);
  static const Color adminDimDark = Color(0xFF6B7280);

  // Theme-aware Getters
  static Color getBackground(bool isDark) => isDark ? backgroundDark : background;
  static Color getSurface(bool isDark) => isDark ? bgSubtleDark : bgSubtle;
  static Color getCard(bool isDark) => isDark ? cardBgDark : cardBg;
  static Color getBorder(bool isDark) => isDark ? borderDark : border;
  static Color getPurple(bool isDark) => isDark ? purpleDark : purple;
  static Color getPurpleLight(bool isDark) => isDark ? purpleLightDark : purpleLight;
  static Color getGreen(bool isDark) => isDark ? greenDark : green;
  static Color getGreenLight(bool isDark) => isDark ? greenLightDark : greenLight;
  static Color getRed(bool isDark) => isDark ? redDark : red;
  static Color getRedLight(bool isDark) => isDark ? redLightDark : redLight;
  
  static Color getPrimaryText(bool isDark) => isDark ? foregroundDark : foreground;
  static Color getSecondaryText(bool isDark) => isDark ? adminLabelDark : adminLabel;
  static Color getDimText(bool isDark) => isDark ? adminDimDark : adminDim;
}

import 'package:flutter/material.dart';

class PaceColors {
  // Brand Design Tokens
  static const Color purple = Color(0xFF4B1D8F);
  static const Color purpleGlow = Color(0xFF9155FD);
  static const Color purpleLight = Color(0xFFF4F0FF);
  static const Color green = Color(0xFF2CB34A);
  static const Color emerald = Color(0xFF10B981);
  static const Color sapphire = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  
  // Surface Colors (Light)
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF111827);
  static const Color border = Color(0xFFE5E7EB);
  static const Color bgSubtle = Color(0xFFF9FAFB);

  // Surface Colors (Dark)
  static const Color purpleDark = Color(0xFF5B2DA0);
  static const Color greenDark = Color(0xFF4ADE80);
  static const Color backgroundDark = Color(0xFF0D0D12);
  static const Color foregroundDark = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFF2D2D3A);
  static const Color bgSubtleDark = Color(0xFF161B22);

  // Admin Palette (Light)
  static const Color adminLabel = Color(0xFF4B5563);
  static const Color adminValue = Color(0xFF111827);
  static const Color adminDim = Color(0xFF9CA3AF);

  // Admin Palette (Dark)
  static const Color adminLabelDark = Color(0xFF9CA3AF);
  static const Color adminValueDark = Color(0xFFF3F4F6);
  static const Color adminDimDark = Color(0xFF6B7280);

  // Theme-aware Getters (Used by recent UI refactors)
  static Color getBackground(bool isDark) => isDark ? backgroundDark : background;
  static Color getSurface(bool isDark) => isDark ? const Color(0xFF16161E) : bgSubtle;
  static Color getCard(bool isDark) => isDark ? const Color(0xFF1C1C26) : background;
  static Color getBorder(bool isDark) => isDark ? borderDark : border;
  
  static Color getPrimaryText(bool isDark) => isDark ? foregroundDark : foreground;
  static Color getSecondaryText(bool isDark) => isDark ? adminLabelDark : adminLabel;
  static Color getDimText(bool isDark) => isDark ? adminDimDark : adminDim;
}

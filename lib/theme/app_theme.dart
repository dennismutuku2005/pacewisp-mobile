import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: PaceColors.purple,
      secondary: PaceColors.green,
      surface: PaceColors.background,
      onSurface: PaceColors.foreground,
    ),
    scaffoldBackgroundColor: PaceColors.background,
    dividerColor: PaceColors.border,
    textTheme: GoogleFonts.figtreeTextTheme().apply(
      bodyColor: PaceColors.adminValue,
      displayColor: PaceColors.adminValue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PaceColors.background,
      foregroundColor: PaceColors.foreground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: PaceColors.purple,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: PaceColors.background,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: PaceColors.purple,
      unselectedItemColor: PaceColors.adminDim,
      backgroundColor: PaceColors.background,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PaceColors.purple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: PaceColors.purpleDark,
      secondary: PaceColors.greenDark,
      surface: PaceColors.backgroundDark,
      onSurface: PaceColors.foregroundDark,
    ),
    scaffoldBackgroundColor: PaceColors.backgroundDark,
    dividerColor: PaceColors.borderDark,
    textTheme: GoogleFonts.figtreeTextTheme().apply(
      bodyColor: PaceColors.adminValueDark,
      displayColor: PaceColors.adminValueDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PaceColors.backgroundDark,
      foregroundColor: PaceColors.foregroundDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: PaceColors.purpleDark,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: PaceColors.backgroundDark,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: PaceColors.purpleDark,
      unselectedItemColor: PaceColors.adminDimDark,
      backgroundColor: PaceColors.backgroundDark,
      type: BottomNavigationBarType.fixed,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PaceColors.purpleDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

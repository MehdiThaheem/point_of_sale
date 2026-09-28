import 'package:flutter/material.dart';

class AppTheme {
  // Company Colors
  static const Color primaryNavy = Color(0xFF03264C);
  static const Color primaryBlue = Color(0xFF2563D9);
  static const Color successGreen = Color(0xFF10A66A);
  static const Color warningOrange = Color(0xFFF2A900);
  static const Color dangerRed = Color(0xFFD93636);

  static const Color background = Color(0xFFF5F7FA);
  static const Color white = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryNavy,
      primary: primaryNavy,
      secondary: primaryBlue,
      surface: white,
      brightness: Brightness.light,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryNavy,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: white,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
        borderSide: BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
        borderSide: BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
        borderSide: BorderSide(
          color: primaryBlue,
          width: 2,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );
}
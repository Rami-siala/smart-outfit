import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const navy = Color(0xFF173B6D);
  static const navySoft = Color(0xFF2B568D);
  static const mist = Color(0xFFF3F7FB);
  static const pink = Color(0xFFD970C4);
  static const coral = Color(0xFFE85B5B);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: navy,
      secondary: pink,
      error: coral,
      surface: Colors.white,
      onSurface: const Color(0xFF18324E),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      canvasColor: mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: mist,
        foregroundColor: navy,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE2E9F2),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F8FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF8D8D8D)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: pink, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFFBBC7D8),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? pink
              : const Color(0xFFD2DBE8),
        ),
      ),
    );
  }
}

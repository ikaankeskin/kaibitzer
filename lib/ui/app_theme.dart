import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF120F0C);
  static const lacquer = Color(0xFF1C1713);
  static const vermillion = Color(0xFFC45C26);
  static const gold = Color(0xFFE8C37A);
  static const paper = Color(0xFFF4E8D0);
}

ThemeData buildKaibitzerTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.vermillion,
    brightness: Brightness.dark,
    surface: AppColors.lacquer,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.paper,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: AppColors.vermillion.withValues(alpha: 0.85),
      backgroundColor: const Color(0xFF2A241E),
      labelStyle: const TextStyle(color: AppColors.paper),
      side: BorderSide.none,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.vermillion,
        foregroundColor: AppColors.paper,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF241E19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

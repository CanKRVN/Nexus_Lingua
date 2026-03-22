import 'package:flutter/material.dart';

/// Cyber-Minimalist tokens (`.cursorrules` §2).
abstract final class AppColors {
  static const Color backgroundPrimary = Color(0xFF0D0D0D);
  static const Color accentCyan = Color(0xFF00BCD4);
  static const Color accentMagenta = Color(0xFFE91E8C);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color textBody = Color(0xFFE0E0E0);
  static const Color textSubtext = Color(0xFF777777);
  static const Color textDisabled = Color(0xFF444444);
  static const Color borderNeutral = Color(0xFF555555);
  static const Color surfaceGlass = Color(0x0DFFFFFF);

  /// FSRS rating row (`.cursorrules` feedback tokens).
  static const Color feedbackCrit = Color(0xFF00E676);
  static const Color feedbackHit = Color(0xFF69F0AE);
  static const Color feedbackHard = Color(0xFFFFD740);
  static const Color feedbackMiss = Color(0xFFFF5252);
}

/// Dark Material 3 theme using only the Nexus palette (no default blues).
ThemeData buildNexusTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundPrimary,
    colorScheme: ColorScheme.dark(
      surface: AppColors.backgroundPrimary,
      primary: AppColors.accentCyan,
      secondary: AppColors.accentMagenta,
      tertiary: AppColors.accentGreen,
      onSurface: AppColors.textBody,
      onPrimary: AppColors.backgroundPrimary,
      outline: AppColors.accentCyan,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundPrimary,
      foregroundColor: AppColors.textBody,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textBody,
      displayColor: AppColors.textBody,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceGlass,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.accentCyan, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceGlass,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentCyan),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.accentCyan.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentCyan, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSubtext),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textBody,
      iconColor: AppColors.accentCyan,
    ),
  );
}

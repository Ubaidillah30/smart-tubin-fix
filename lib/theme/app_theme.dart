import 'package:flutter/material.dart';

/// Palet warna — mendukung dark & light mode.
class AppColors {
  // --- Dark mode ---
  static const bgDark = Color(0xFF0E1116);
  static const cardDark = Color(0xFF171B21);
  static const cardDarkAlt = Color(0xFF1D2229);
  static const accentGreen = Color(0xFF34D399);
  static const accentGreenDark = Color(0xFF10B981);
  static const textPrimary = Color(0xFFF3F4F6);
  static const textSecondary = Color(0xFF9CA3AF);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // --- Light mode specific ---
  static const bgLight = Color(0xFFF0F4F8);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardLightAlt = Color(0xFFEDF2F7);
  static const textPrimaryLight = Color(0xFF1A202C);
  static const textSecondaryLight = Color(0xFF4A5568);
}

/// Helper: ambil warna berdasarkan brightness context.
extension AppColorsExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get cardColor =>
      isDark ? AppColors.cardDark : AppColors.cardLight;

  Color get cardAltColor =>
      isDark ? AppColors.cardDarkAlt : AppColors.cardLightAlt;

  Color get textPrimaryColor =>
      isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

  Color get textSecondaryColor =>
      isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    primaryColor: AppColors.accentGreen,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.cardDark,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDark,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accentGreenDark;
        }
        return const Color(0xFF3A3F47);
      }),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: AppColors.textPrimary),
    ),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bgLight,
    primaryColor: AppColors.accentGreenDark,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: AppColors.accentGreenDark,
      secondary: AppColors.accentGreenDark,
      surface: AppColors.cardLight,
      onSurface: AppColors.textPrimaryLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
      titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accentGreenDark;
        }
        return const Color(0xFFCBD5E0);
      }),
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimaryLight),
      bodySmall: TextStyle(color: AppColors.textSecondaryLight),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: AppColors.textPrimaryLight),
    ),
  );
}

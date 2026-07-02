import 'package:flutter/material.dart';

/// Premium design system — dark-first with refined surfaces and gradient accents.
class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF7C5CFC);
  static const _surfaceDark = Color(0xFF0D0D14);
  static const _cardDark = Color(0xFF161622);
  static const _borderDark = Color(0xFF252535);
  static const _textPrimary = Color(0xFFF0EDFA);
  static const _textMuted = Color(0xFF8B8A9A);

  static const _surfaceLight = Color(0xFFFAFAFE);
  static const _cardLight = Color(0xFFFFFFFF);
  static const _borderLight = Color(0xFFE8E8F0);
  static const _textPrimaryLight = Color(0xFF1A1A28);
  static const _textMutedLight = Color(0xFF8E8D9E);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _surfaceDark,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.white,
      surface: _surfaceDark,
      onSurface: _textPrimary,
      surfaceContainerHighest: _cardDark,
      outline: _borderDark,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15, color: _textPrimary),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _textPrimary),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: _textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textPrimary),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.55, color: _textPrimary),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, color: _textMuted),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.35, color: _textMuted),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: _textPrimary),
    ),
    cardTheme: CardThemeData(
      color: _cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _borderDark)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surfaceDark,
      elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary),
      iconTheme: IconThemeData(color: _textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: _cardDark,
      hintStyle: const TextStyle(color: _textMuted, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surfaceDark,
      indicatorColor: _primary.withValues(alpha: 0.12),
      elevation: 0, height: 60,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? _primary : _textMuted, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 10, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400, color: s.contains(WidgetState.selected) ? _primary : _textMuted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _cardDark,
      contentTextStyle: const TextStyle(color: _textPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: _borderDark, thickness: 0.5),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _surfaceLight,
    colorScheme: const ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      surface: _surfaceLight,
      onSurface: _textPrimaryLight,
      surfaceContainerHighest: _cardLight,
      outline: _borderLight,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15, color: _textPrimaryLight),
      headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _textPrimaryLight),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: _textPrimaryLight),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimaryLight),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _textPrimaryLight),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.55, color: _textPrimaryLight),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, color: _textMutedLight),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.35, color: _textMutedLight),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: _textPrimaryLight),
    ),
    cardTheme: CardThemeData(
      color: _cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _borderLight)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _surfaceLight,
      elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimaryLight),
      iconTheme: IconThemeData(color: _textPrimaryLight),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: _cardLight,
      hintStyle: const TextStyle(color: _textMutedLight, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _surfaceLight,
      indicatorColor: _primary.withValues(alpha: 0.08),
      elevation: 0, height: 60,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? _primary : _textMutedLight, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 10, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400, color: s.contains(WidgetState.selected) ? _primary : _textMutedLight)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1C1C28),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: _borderLight, thickness: 0.5),
  );
}

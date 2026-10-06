import 'package:flutter/material.dart';

abstract final class DiaryTheme {
  static const primary = Color(0xFF08786C);
  static const ink = Color(0xFF163B37);
  static const muted = Color(0xFF5A716C);
  static const background = Color(0xFFF0F7F4);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFD7E7DF);
  static const danger = Color(0xFFB3261E);
  static const cash = Color(0xFF8D422E);
  static const cashSurface = Color(0xFFFFEDE7);
  static const cardSurface = Color(0xFFE1F3EB);
  static const incomeSurface = Color(0xFFC9F1E4);
  static const coral = Color(0xFFFFAD98);
  static const onCoral = Color(0xFF502B24);
  static const radius = 24.0;
  static const pageMax = 1240.0;

  static TextStyle number(double size, {Color? color}) => TextStyle(
    fontFamily: 'Bahnschrift',
    fontFamilyFallback: const ['Arial', 'sans-serif'],
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: color ?? ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Arial', 'sans-serif'],
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: surface,
      secondary: ink,
      primaryContainer: incomeSurface,
      onPrimaryContainer: ink,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: muted,
      outlineVariant: border,
      error: danger,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: surface),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: ink,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? surface : ink,
        ),
        minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thumbColor: const WidgetStatePropertyAll(muted),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
  );
}

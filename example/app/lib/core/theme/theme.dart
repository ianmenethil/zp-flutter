/// Zenith brand [ThemeData] for the sample app.
///
/// - [_zpRed] / [_zpRedDark] — accent (CTAs, errors, logo).
/// - [_zpInk] — primary text/ink.
/// - [_statusWarning] / [_statusWarningBg] — warning status colours.
/// - [ZenithTheme] — builds light/dark [ThemeData]; SDK widgets inherit ambient Theme.
library;

import 'package:flutter/material.dart';

const _zpRed = Color(0xFFD71F26);
const _zpRedDark = Color(0xFFE83239);
const _zpInk = Color(0xFF1C1C1C);
const _statusWarning = Color(0xFFC97A12);
const _statusWarningBg = Color(0xFFFDF3E2);
const _fontFamily = 'Poppins';

/// Factory for light/dark themes from Zenith design tokens.
final class ZenithTheme {
  const ZenithTheme._();

  /// Builds the light [ThemeData].
  static ThemeData light() => _theme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _zpRed,
      secondary: _zpInk,
      onSecondary: Colors.white,
      tertiary: _statusWarning,
      onTertiary: Colors.white,
      tertiaryContainer: _statusWarningBg,
      onTertiaryContainer: _zpInk,
      error: _zpRed,
      errorContainer: Color(0xFFFCE8E9),
      onErrorContainer: _zpInk,
      onSurface: _zpInk,
      onSurfaceVariant: Color(0xFF6E6E6E),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFAFA),
      surfaceContainer: Color(0xFFF4F4F4),
      surfaceContainerHigh: Color(0xFFF4F4F4),
      outline: Color(0xFFD1D1D1),
      outlineVariant: Color(0xFFE7E7E7),
    ),
  );

  /// Builds the dark [ThemeData].
  static ThemeData dark() => _theme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _zpRedDark,
      onPrimary: Colors.white,
      secondary: Color(0xFFF4F4F4),
      onSecondary: _zpInk,
      tertiary: _statusWarning,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0x28C97A12),
      onTertiaryContainer: Color(0xFFF4F4F4),
      error: _zpRedDark,
      onError: Colors.white,
      errorContainer: Color(0x24E83239),
      onErrorContainer: Color(0xFFF4F4F4),
      surface: Color(0xFF0F0F0F),
      onSurface: Color(0xFFF4F4F4),
      onSurfaceVariant: Color(0xFF9E9E9E),
      surfaceContainerLowest: Color(0xFF0F0F0F),
      surfaceContainerLow: Color(0xFF161616),
      surfaceContainer: Color(0xFF1F1F1F),
      surfaceContainerHigh: Color(0xFF1F1F1F),
      outline: Color(0xFF353535),
      outlineVariant: Color(0xFF262626),
    ),
  );

  /// Shared theme builder — [light] and [dark] only differ in [colorScheme].
  static ThemeData _theme({required Brightness brightness, required ColorScheme colorScheme}) {
    final base = ThemeData(brightness: brightness, fontFamily: _fontFamily).textTheme;
    // Headings: Monument Bold is unavailable, so weight 900 Poppins stands
    // in for it per the design system's own documented fallback.
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.02),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.02),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.01),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.01),
    );

    const pillShape = StadiumBorder();
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      textTheme: textTheme,
      dividerColor: colorScheme.outlineVariant,
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pillShape,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.01),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pillShape,
          side: BorderSide(color: colorScheme.outline),
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pillShape,
          foregroundColor: colorScheme.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    );
  }
}

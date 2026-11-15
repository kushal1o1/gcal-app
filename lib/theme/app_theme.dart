import 'package:flutter/material.dart';

/// Terminal palette lifted straight from the landing page
/// (internal/server/landing.go). Light & dark follow the system, like the
/// page's `prefers-color-scheme` blocks.
class AppColors {
  AppColors._();

  // dark
  static const darkBg = Color(0xFF05070A);
  static const darkSurface = Color(0xFF0A1420);
  static const darkInk = Color(0xFFCdebFF);
  static const darkDim = Color(0xFF5B7A8C);
  static const darkBlue = Color(0xFF89B4FA);
  static const darkPink = Color(0xFFF38BA8);
  static const darkHair = Color(0xFF16232B);

  // light
  static const lightBg = Color(0xFFEEF2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF1C2B3A);
  static const lightDim = Color(0xFF6B7C8C);
  static const lightBlue = Color(0xFF2F6FD6);
  static const lightPink = Color(0xFFD6467C);
  static const lightHair = Color(0xFFD3DCE4);

  /// Adaptive logo "mark" color (the in-tile G + notch), matching the page's
  /// `--logo-mark` variable.
  static const darkMark = Color(0xFF05070A);
  static const lightMark = Color(0xFFFFFFFF);
}

/// Brand sprite for the current brightness (term colors are not symmetric —
/// the accent fills swap between the two modes, like the landing's CSS).
abstract final class GcalPalette {
  static Color bg(bool d) => d ? AppColors.darkBg : AppColors.lightBg;
  static Color surface(bool d) => d ? AppColors.darkSurface : AppColors.lightSurface;
  static Color ink(bool d) => d ? AppColors.darkInk : AppColors.lightInk;
  static Color dim(bool d) => d ? AppColors.darkDim : AppColors.lightDim;
  static Color blue(bool d) => d ? AppColors.darkBlue : AppColors.lightBlue;
  static Color pink(bool d) => d ? AppColors.darkPink : AppColors.lightPink;
  static Color hair(bool d) => d ? AppColors.darkHair : AppColors.lightHair;
  static Color mark(bool d) => d ? AppColors.darkMark : AppColors.lightMark;

  /// Text color used on top of a [blue] fill.
  static Color onBlue(bool d) => d ? AppColors.darkMark : Colors.white;
}

ThemeData buildGcalTheme(Brightness brightness) {
  final d = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: GcalPalette.blue(d),
    brightness: brightness,
  ).copyWith(
    primary: GcalPalette.blue(d),
    onPrimary: GcalPalette.onBlue(d),
    secondary: GcalPalette.pink(d),
    onSecondary: GcalPalette.mark(d),
    error: GcalPalette.pink(d),
    onError: GcalPalette.mark(d),
    surface: GcalPalette.surface(d),
    onSurface: GcalPalette.ink(d),
    onSurfaceVariant: GcalPalette.dim(d),
    outline: GcalPalette.hair(d),
    outlineVariant: GcalPalette.hair(d),
    surfaceContainerLowest: GcalPalette.bg(d),
    surfaceContainerLow: GcalPalette.surface(d),
    surfaceContainer: GcalPalette.surface(d),
    surfaceContainerHigh: GcalPalette.surface(d),
    surfaceContainerHighest: GcalPalette.hair(d),
    primaryContainer: GcalPalette.surface(d),
    onPrimaryContainer: GcalPalette.ink(d),
    secondaryContainer: GcalPalette.surface(d),
    onSecondaryContainer: GcalPalette.ink(d),
    errorContainer: GcalPalette.surface(d),
    onErrorContainer: GcalPalette.pink(d),
  );

  final hairline = BorderSide(color: GcalPalette.hair(d), width: 1);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'monospace',
    colorScheme: scheme,
    scaffoldBackgroundColor: GcalPalette.bg(d),
    appBarTheme: AppBarTheme(
      backgroundColor: GcalPalette.bg(d),
      foregroundColor: GcalPalette.ink(d),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: GcalPalette.surface(d),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: hairline,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: GcalPalette.surface(d),
      selectedColor: GcalPalette.blue(d),
      disabledColor: GcalPalette.surface(d),
      labelStyle: TextStyle(color: GcalPalette.ink(d), fontSize: 12),
      secondaryLabelStyle: TextStyle(color: GcalPalette.onBlue(d), fontSize: 12),
      side: hairline,
      shape: const StadiumBorder(),
      padding: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GcalPalette.surface(d),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: hairline,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: GcalPalette.surface(d),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: GcalPalette.surface(d),
      contentTextStyle: TextStyle(color: GcalPalette.ink(d)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: hairline,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      hintStyle: TextStyle(color: GcalPalette.dim(d)),
      labelStyle: TextStyle(color: GcalPalette.dim(d)),
      border: const UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(borderSide: hairline),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: GcalPalette.blue(d), width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(color: GcalPalette.hair(d), thickness: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: GcalPalette.surface(d),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: hairline,
      ),
      textStyle: TextStyle(color: GcalPalette.ink(d)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: GcalPalette.blue(d),
      selectionColor: GcalPalette.pink(d).withValues(alpha: 0.3),
      selectionHandleColor: GcalPalette.pink(d),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GcalPalette.blue(d),
        foregroundColor: GcalPalette.onBlue(d),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GcalPalette.blue(d),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        side: hairline,
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: GcalPalette.blue(d)),
    ),
  );
}

/// Adaptive "negative space" for the logo glyph — the landing page's
/// `--logo-mark` variable.
Color gcalKeyColor(ThemeData theme) =>
    GcalPalette.mark(theme.brightness == Brightness.dark);
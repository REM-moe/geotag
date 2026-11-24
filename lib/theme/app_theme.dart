import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// When true (golden/screenshot tests only), uses locally loaded Figtree &
/// JetBrainsMono families instead of runtime GoogleFonts HTTP fetching.
@visibleForTesting
bool kUseLocalTestFonts = false;

/// Monospace style for coordinates, altitude, timestamps.
TextStyle monoStyle({double size = TextSize.xs, Color? color, FontWeight? weight}) =>
    kUseLocalTestFonts
        ? TextStyle(fontFamily: 'JetBrainsMono', fontSize: size, color: color, fontWeight: weight)
        : GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

ThemeData buildTheme(Brightness brightness) {
  final g = brightness == Brightness.dark ? GeoColors.dark : GeoColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: g.accent,
    onPrimary: g.onAccent,
    secondary: g.text,
    onSecondary: g.bg,
    error: g.negative,
    onError: Colors.white,
    surface: g.bg,
    onSurface: g.text,
    onSurfaceVariant: g.text2,
    outline: g.borderStrong,
    outlineVariant: g.border,
    surfaceContainerLowest: g.bg,
    surfaceContainerLow: g.surface,
    surfaceContainer: g.surface,
    surfaceContainerHigh: g.surface2,
    surfaceContainerHighest: g.surface3,
    inverseSurface: g.text,
    onInverseSurface: g.bg,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: g.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  final text = (kUseLocalTestFonts
          ? base.textTheme.apply(fontFamily: 'Figtree')
          : GoogleFonts.figtreeTextTheme(base.textTheme))
      .apply(
    bodyColor: g.text,
    displayColor: g.text,
  );

  final hairline = BorderSide(color: g.border);
  final rMd = BorderRadius.circular(Radii.md);

  return base.copyWith(
    textTheme: text,
    extensions: [g],
    dividerTheme: DividerThemeData(color: g.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: g.bg,
      foregroundColor: g.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: g.bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: hairline),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: g.accent,
        foregroundColor: g.onAccent,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        shape: RoundedRectangleBorder(borderRadius: rMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: TextSize.md),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: g.text,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        side: BorderSide(color: g.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: rMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: TextSize.md),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: g.text2,
        shape: RoundedRectangleBorder(borderRadius: rMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: TextSize.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: g.bg,
      hintStyle: TextStyle(color: g.text3),
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s3),
      border: OutlineInputBorder(borderRadius: rMd, borderSide: BorderSide(color: g.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: rMd, borderSide: BorderSide(color: g.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: rMd, borderSide: BorderSide(color: g.accent, width: 1.5)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? g.accent : g.surface3,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: g.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: g.borderStrong,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: g.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? g.text : g.text3,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? g.text : g.text3),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: g.text,
      contentTextStyle: TextStyle(color: g.bg, fontSize: TextSize.sm, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: rMd),
    ),
  );
}

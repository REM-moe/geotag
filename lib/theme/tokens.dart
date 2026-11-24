import 'package:flutter/material.dart';

/// Astryx-style design tokens.
///
/// Rules:
///  * Neutral greys everywhere. Colour ([GeoColors.accent], positive, warning,
///    negative) is reserved for interactive elements and status feedback.
///  * 1px hairline borders instead of shadows.
///  * Strict 4pt spacing scale — never use magic numbers in widgets.
///  * Restrained radii.
abstract final class Space {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
}

abstract final class Radii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 999;
}

abstract final class TextSize {
  static const double xs = 11;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 26;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Curve ease = Cubic(0.2, 0, 0, 1);
}

/// Semantic colour tokens, exposed as a [ThemeExtension] so every widget reads
/// `context.geo.border` etc. instead of hard-coding colours.
@immutable
class GeoColors extends ThemeExtension<GeoColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color positive;
  final Color positiveSoft;
  final Color warning;
  final Color warningSoft;
  final Color negative;
  final Color negativeSoft;

  const GeoColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.positive,
    required this.positiveSoft,
    required this.warning,
    required this.warningSoft,
    required this.negative,
    required this.negativeSoft,
  });

  static const light = GeoColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAFA),
    surface2: Color(0xFFF4F4F5),
    surface3: Color(0xFFE9E9EB),
    border: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFD4D4D8),
    text: Color(0xFF18181B),
    text2: Color(0xFF52525B),
    text3: Color(0xFFA1A1AA),
    accent: Color(0xFF0866FF),
    accentSoft: Color(0xFFEBF2FF),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF1A7F37),
    positiveSoft: Color(0xFFE8F5EC),
    warning: Color(0xFF9A6700),
    warningSoft: Color(0xFFFFF6E0),
    negative: Color(0xFFCF222E),
    negativeSoft: Color(0xFFFDECEC),
  );

  static const dark = GeoColors(
    bg: Color(0xFF0B0B0C),
    surface: Color(0xFF121214),
    surface2: Color(0xFF19191C),
    surface3: Color(0xFF232327),
    border: Color(0xFF26262A),
    borderStrong: Color(0xFF34343A),
    text: Color(0xFFF4F4F5),
    text2: Color(0xFFA1A1AA),
    text3: Color(0xFF63636B),
    accent: Color(0xFF4C8DFF),
    accentSoft: Color(0xFF14213A),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF3FB950),
    positiveSoft: Color(0xFF11261A),
    warning: Color(0xFFD29922),
    warningSoft: Color(0xFF2A2110),
    negative: Color(0xFFF85149),
    negativeSoft: Color(0xFF2D1517),
  );

  /// Camera chrome is always dark regardless of system theme.
  static const camera = dark;

  @override
  GeoColors copyWith() => this;

  @override
  GeoColors lerp(ThemeExtension<GeoColors>? other, double t) {
    if (other is! GeoColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return GeoColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      surface3: l(surface3, other.surface3),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      positive: l(positive, other.positive),
      positiveSoft: l(positiveSoft, other.positiveSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      negative: l(negative, other.negative),
      negativeSoft: l(negativeSoft, other.negativeSoft),
    );
  }
}

extension GeoThemeX on BuildContext {
  GeoColors get geo => Theme.of(this).extension<GeoColors>() ?? GeoColors.light;
}

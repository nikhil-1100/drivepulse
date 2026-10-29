
import 'package:flutter/material.dart';

/// Type ramp from the DrivePulse design spec.
///
/// Plus Jakarta Sans carries the interface, JetBrains Mono carries telemetry.
/// Both ship as variable fonts, so every style also sets a `wght` axis — that
/// is what makes the numbers in the gauges look crisp instead of synthetically
/// emboldened.
abstract final class AppType {
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';

  static TextStyle _style({
    required String family,
    required double size,
    required FontWeight weight,
    required double lineHeight,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: <FontVariation>[FontVariation('wght', weight.value.toDouble())],
    );
  }

  static TextStyle displayLarge(Color color) => _style(
        family: sans,
        size: 36,
        weight: FontWeight.w700,
        lineHeight: 44,
        letterSpacing: -0.72,
        color: color,
      );

  static TextStyle displayMedium(Color color) => _style(
        family: sans,
        size: 28,
        weight: FontWeight.w700,
        lineHeight: 34,
        letterSpacing: -0.42,
        color: color,
      );

  static TextStyle headlineLarge(Color color) => _style(
        family: sans,
        size: 24,
        weight: FontWeight.w600,
        lineHeight: 32,
        letterSpacing: -0.24,
        color: color,
      );

  static TextStyle headlineMedium(Color color) => _style(
        family: sans,
        size: 20,
        weight: FontWeight.w600,
        lineHeight: 28,
        color: color,
      );

  static TextStyle headlineSmall(Color color) => _style(
        family: sans,
        size: 16,
        weight: FontWeight.w600,
        lineHeight: 24,
        color: color,
      );

  static TextStyle bodyLarge(Color color) => _style(
        family: sans,
        size: 16,
        weight: FontWeight.w400,
        lineHeight: 24,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => _style(
        family: sans,
        size: 14,
        weight: FontWeight.w400,
        lineHeight: 20,
        color: color,
      );

  static TextStyle bodySmall(Color color) => _style(
        family: sans,
        size: 12,
        weight: FontWeight.w400,
        lineHeight: 16,
        color: color,
      );

  static TextStyle labelLarge(Color color) => _style(
        family: sans,
        size: 14,
        weight: FontWeight.w600,
        lineHeight: 20,
        color: color,
      );

  static TextStyle metricLarge(Color color) => _style(
        family: mono,
        size: 28,
        weight: FontWeight.w600,
        lineHeight: 32,
        letterSpacing: -0.84,
        color: color,
      );

  static TextStyle metricMedium(Color color) => _style(
        family: mono,
        size: 18,
        weight: FontWeight.w600,
        lineHeight: 24,
        letterSpacing: -0.36,
        color: color,
      );

  static TextStyle metricSmall(Color color) => _style(
        family: mono,
        size: 13,
        weight: FontWeight.w500,
        lineHeight: 18,
        color: color,
      );

  static TextStyle monoSmall(Color color) => metricSmall(color);

  static TextStyle monoMedium(Color color) => metricMedium(color);

  /// Uppercase monospace micro-label used on protocol pills and section rails.
  static TextStyle labelCaps(Color color) => _style(
        family: mono,
        size: 11,
        weight: FontWeight.w600,
        lineHeight: 14,
        letterSpacing: 0.66,
        color: color,
      );

  static TextTheme textTheme(Color text, Color muted) {
    return TextTheme(
      displayLarge: displayLarge(text),
      displayMedium: displayMedium(text),
      displaySmall: displayMedium(text),
      headlineLarge: headlineLarge(text),
      headlineMedium: headlineMedium(text),
      headlineSmall: headlineSmall(text),
      titleLarge: headlineLarge(text),
      titleMedium: headlineSmall(text),
      titleSmall: labelLarge(text),
      bodyLarge: bodyLarge(text),
      bodyMedium: bodyMedium(text),
      bodySmall: bodySmall(muted),
      labelLarge: labelLarge(text),
      labelMedium: labelCaps(muted),
      labelSmall: labelCaps(muted),
    );
  }
}

/// Single source of truth for metrics that the design system repeats.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Outer screen margin.
  static const double screen = 16;

  /// Maximum content width on tablets / desktop.
  static const double maxContent = 1120;
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double card = 20;
  static const double lg = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

abstract final class DpDurations {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration xslow = Duration(milliseconds: 900);
}

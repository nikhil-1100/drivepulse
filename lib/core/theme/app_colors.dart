import 'package:flutter/material.dart';

/// DrivePulse colour system.
///
/// The palette follows the Stitch "Kinetic Drive Precision" spec: warm cream
/// canvas, obsidian structure and signal-red telemetry. Both light and dark
/// variants are first-class because the manager is used in the field, often at
/// night or inside a server rack.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.primaryDeep,
    required this.onPrimary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.obsidian,
    required this.onObsidian,
    required this.gaugeTrack,
    required this.shadow,
  });

  /// Page background.
  final Color canvas;

  /// Raised card surface.
  final Color surface;

  /// Secondary surface (chips, inset fields, sub-cards).
  final Color surfaceAlt;

  /// Recessed surface (track fills, skeletons).
  final Color surfaceSunken;

  /// Hairline outline.
  final Color border;

  /// Stronger outline for inputs and focused states.
  final Color borderStrong;

  /// Primary text.
  final Color text;

  /// Secondary text / metadata.
  final Color textMuted;

  /// Disabled or tertiary text.
  final Color textFaint;

  /// Signal red — primary action and active telemetry.
  final Color primary;

  /// Pressed / hover state of [primary].
  final Color primaryDeep;

  /// Text and icons on [primary].
  final Color onPrimary;

  /// Tinted red surface.
  final Color primarySoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// Dark structural panel.
  final Color obsidian;

  /// Content on [obsidian].
  final Color onObsidian;

  /// Empty portion of a gauge or progress track.
  final Color gaugeTrack;

  /// Ambient card shadow.
  final Color shadow;

  static const AppColors light = AppColors(
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F2EB),
    surfaceSunken: Color(0xFFEDE8E0),
    border: Color(0xFFE7E5E4),
    borderStrong: Color(0xFFD6D3D1),
    text: Color(0xFF0A0A0A),
    textMuted: Color(0xFF78716C),
    textFaint: Color(0xFFA8A29E),
    primary: Color(0xFFF03A3A),
    primaryDeep: Color(0xFF990011),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFFFECEC),
    success: Color(0xFF059669),
    successSoft: Color(0xFFE7F8F2),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFDF4E3),
    danger: Color(0xFFBA1A1A),
    dangerSoft: Color(0xFFFFDAD6),
    info: Color(0xFF475569),
    infoSoft: Color(0xFFF1F5F9),
    obsidian: Color(0xFF0A0A0A),
    onObsidian: Color(0xFFFAF7F2),
    gaugeTrack: Color(0xFFE7E5E4),
    shadow: Color(0x140A0A0A),
  );

  static const AppColors dark = AppColors(
    canvas: Color(0xFF0B0C10),
    surface: Color(0xFF17181C),
    surfaceAlt: Color(0xFF1E1F24),
    surfaceSunken: Color(0xFF26272E),
    border: Color(0xFF2A2B31),
    borderStrong: Color(0xFF3A3B42),
    text: Color(0xFFF1F5F9),
    textMuted: Color(0xFFA1A1AA),
    textFaint: Color(0xFF71717A),
    primary: Color(0xFFF43F5E),
    primaryDeep: Color(0xFFBE123C),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x2EF43F5E),
    success: Color(0xFF34D399),
    successSoft: Color(0x1F10B981),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x1FFBBF24),
    danger: Color(0xFFEF4444),
    dangerSoft: Color(0x24EF4444),
    info: Color(0xFF94A3B8),
    infoSoft: Color(0x1F94A3B8),
    obsidian: Color(0xFFF1F5F9),
    onObsidian: Color(0xFF0B0C10),
    gaugeTrack: Color(0xFF26272E),
    shadow: Color(0x66000000),
  );

  bool get isDark => canvas.computeLuminance() < 0.2;

  @override
  AppColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? primary,
    Color? primaryDeep,
    Color? onPrimary,
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? obsidian,
    Color? onObsidian,
    Color? gaugeTrack,
    Color? shadow,
  }) {
    return AppColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      primary: primary ?? this.primary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      obsidian: obsidian ?? this.obsidian,
      onObsidian: onObsidian ?? this.onObsidian,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDeep: Color.lerp(primaryDeep, other.primaryDeep, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      obsidian: Color.lerp(obsidian, other.obsidian, t)!,
      onObsidian: Color.lerp(onObsidian, other.onObsidian, t)!,
      gaugeTrack: Color.lerp(gaugeTrack, other.gaugeTrack, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Convenience accessor so widgets read `context.colors` instead of digging
/// through `Theme.of(context).extension<AppColors>()`.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

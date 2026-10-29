import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_type.dart';

/// Builds the two DrivePulse themes. Everything visual — including the
/// "instrument panel" feel of inputs and switches — is defined here so screens
/// never hand-roll one-off styles.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primaryDeep,
      secondary: c.obsidian,
      onSecondary: c.onObsidian,
      secondaryContainer: c.surfaceAlt,
      onSecondaryContainer: c.text,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: c.surfaceAlt,
      onSurfaceVariant: c.textMuted,
      outline: c.borderStrong,
      outlineVariant: c.border,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
    );

    final TextTheme typography = AppType.textTheme(c.text, c.textMuted);
    final SystemUiOverlayStyle overlay = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.canvas,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: c.canvas,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      textTheme: typography,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: typography.headlineMedium,
        toolbarHeight: 60,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: c.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        modalBarrierColor: c.obsidian.withValues(alpha: 0.35),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: typography.headlineMedium,
        contentTextStyle: typography.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.obsidian,
        contentTextStyle: typography.bodyMedium?.copyWith(color: c.onObsidian),
        actionTextColor: c.primary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(Insets.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: 14,
        ),
        hintStyle: typography.bodyMedium?.copyWith(color: c.textFaint),
        labelStyle: typography.bodyMedium?.copyWith(color: c.textMuted),
        errorStyle: typography.bodySmall?.copyWith(color: c.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.text, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceSunken,
          disabledForegroundColor: c.textFaint,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          textStyle: typography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
          textStyle: typography.labelLarge,
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: typography.labelLarge,
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          highlightColor: c.surfaceAlt,
        ),
      ),
      iconTheme: IconThemeData(color: c.text, size: 22),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.onPrimary
              : c.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : c.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceSunken,
        circularTrackColor: c.surfaceSunken,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.surfaceAlt,
        labelStyle: typography.bodySmall,
        secondaryLabelStyle: typography.bodySmall?.copyWith(color: c.onPrimary),
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.obsidian,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: typography.bodySmall?.copyWith(color: c.onObsidian),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

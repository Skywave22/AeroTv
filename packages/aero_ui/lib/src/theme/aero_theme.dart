import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aero_colors.dart';
import 'brand_config.dart';

/// Strict type scale. Sizes are generous because TV viewing distance is ~3m.
class AeroType {
  const AeroType._();

  static const family = 'Inter';

  static const displayLarge = TextStyle(
      fontSize: 40, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.8);
  static const displayMedium = TextStyle(
      fontSize: 32, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const headline = TextStyle(
      fontSize: 24, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.3);
  static const title = TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w400);
  static const label = TextStyle(
      fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.3);
  static const caption = TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500);
}

class AeroTheme {
  const AeroTheme._();

  /// Builds the dark theme. [accent] may be derived from artwork.
  static ThemeData dark({
    BrandConfig brand = BrandConfig.standard,
    Color? accent,
    bool tvMode = false,
  }) {
    final seed = accent ?? brand.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AeroColors.surface,
      primary: seed,
      secondary: brand.secondaryGlow,
      error: AeroColors.danger,
      outline: AeroColors.outline,
    );

    // TV needs larger text and hit targets than a phone held at arm's length.
    final scale = tvMode ? 1.18 : 1.0;
    TextStyle s(TextStyle base) => base.copyWith(
          fontFamily: AeroType.family,
          fontSize: (base.fontSize ?? 14) * scale,
          color: AeroColors.textPrimary,
        );

    final textTheme = TextTheme(
      displayLarge: s(AeroType.displayLarge),
      displayMedium: s(AeroType.displayMedium),
      headlineMedium: s(AeroType.headline),
      titleLarge: s(AeroType.title),
      titleMedium: s(AeroType.title.copyWith(fontSize: 16)),
      bodyLarge: s(AeroType.body),
      bodyMedium: s(AeroType.bodySmall),
      labelLarge: s(AeroType.label),
      labelSmall: s(AeroType.caption),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AeroColors.background,
      canvasColor: AeroColors.background,
      fontFamily: AeroType.family,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: AeroColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(
        color: AeroColors.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AeroColors.surfaceHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AeroColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AeroColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AeroColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          minimumSize: Size(tvMode ? 160 : 120, tvMode ? 56 : 48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AeroColors.textPrimary,
          side: const BorderSide(color: AeroColors.outline),
          minimumSize: Size(tvMode ? 160 : 120, tvMode ? 56 : 48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AeroColors.surfaceHigh,
        selectedColor: seed.withValues(alpha: 0.22),
        side: const BorderSide(color: AeroColors.outline),
        labelStyle: textTheme.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AeroColors.surface.withValues(alpha: 0.92),
        indicatorColor: seed.withValues(alpha: 0.22),
        height: tvMode ? 80 : 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AeroColors.surface,
        selectedIconTheme: IconThemeData(color: seed),
        unselectedIconTheme: const IconThemeData(color: AeroColors.textTertiary),
        indicatorColor: seed.withValues(alpha: 0.20),
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AeroColors.surfaceHigher,
        contentTextStyle: textTheme.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AeroColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AeroColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: seed,
        inactiveTrackColor: AeroColors.surfaceHigher,
        thumbColor: Colors.white,
        overlayColor: seed.withValues(alpha: 0.18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? seed : AeroColors.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? seed.withValues(alpha: 0.35)
              : AeroColors.surfaceHigher,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AeroColors.textSecondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: AeroColors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AeroColors.surfaceHigher,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall,
      ),
    );
  }
}

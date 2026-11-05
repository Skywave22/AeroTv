import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Layout class driving the adaptive shell.
enum FormFactor { phone, tablet, desktop, tv }

class Adaptive {
  const Adaptive._();

  /// Detects Android TV / Fire TV from the platform + screen size.
  ///
  /// `isTv` should come from the native side (UiModeManager) when available;
  /// the size heuristic is a safe fallback for desktop-sized windows.
  static FormFactor detect(BuildContext context, {bool isTv = false}) {
    if (isTv) return FormFactor.tv;
    final size = MediaQuery.sizeOf(context);
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return FormFactor.desktop;
    }
    if (size.shortestSide >= 600) return FormFactor.tablet;
    return FormFactor.phone;
  }

  static bool usesSideRail(FormFactor f) => f != FormFactor.phone;

  static bool isLargeScreen(FormFactor f) =>
      f == FormFactor.tv || f == FormFactor.desktop || f == FormFactor.tablet;

  /// Poster width per form factor. TV posters are much larger for couch use.
  static double posterWidth(FormFactor f) => switch (f) {
        FormFactor.phone => 116,
        FormFactor.tablet => 140,
        FormFactor.desktop => 156,
        FormFactor.tv => 190,
      };

  static double rowHeight(FormFactor f) => posterWidth(f) * 1.5 + 56;

  /// Grid columns for search/library.
  static int gridColumns(FormFactor f, double width) {
    final target = posterWidth(f) + 20;
    final cols = (width / target).floor();
    return cols.clamp(2, 8);
  }

  static double heroHeight(FormFactor f, Size size) => switch (f) {
        FormFactor.phone => size.height * 0.42,
        FormFactor.tablet => size.height * 0.46,
        FormFactor.desktop => size.height * 0.52,
        FormFactor.tv => size.height * 0.58,
      };
}

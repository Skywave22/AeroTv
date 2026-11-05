import 'package:flutter/material.dart';

/// OLED-friendly near-black surface ramp. Deliberately low-contrast between
/// steps so large dark areas don't band on cheap TV panels.
class AeroColors {
  const AeroColors._();

  static const background = Color(0xFF08090C);
  static const surface = Color(0xFF0F1116);
  static const surfaceHigh = Color(0xFF171A21);
  static const surfaceHigher = Color(0xFF20242D);
  static const outline = Color(0xFF2A2F3A);

  static const textPrimary = Color(0xFFF2F4F8);
  static const textSecondary = Color(0xFFA8B0C0);
  static const textTertiary = Color(0xFF6C7484);

  static const success = Color(0xFF3DDC97);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5C7A);
  static const info = Color(0xFF3DA5FF);

  /// Scrim used behind hero text so artwork never hurts legibility.
  static const heroScrim = [
    Color(0x00000000),
    Color(0x66000000),
    Color(0xE608090C),
  ];
}

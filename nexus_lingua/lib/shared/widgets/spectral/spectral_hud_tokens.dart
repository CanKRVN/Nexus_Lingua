import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Spectral HUD — shared blur, overlay, and FSRS node accent colors.
abstract final class SpectralHudTokens {
  static const double blurSigma = 20;

  /// Frosted overlay tint strength (on top of glass fill).
  static double overlayOpacity(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? 0.035 : 0.045;

  /// Angled corner cut (logical px) for mastery / blade clips.
  static const double angledCut = 28;

  /// FSRS node glow colors (Again → Easy).
  static const Color nodeAgain = Color(0xFFE040FB); // magenta
  static const Color nodeHard = Color(0xFF2979FF); // blue
  static const Color nodeGood = Color(0xFF00FF41); // matrix green
  static const Color nodeEasy = Color(0xFF00BCD4); // accent cyan (PRD / .cursorrules)

  /// Crit burst particles.
  static const List<Color> critParticleColors = [
    Color(0xFF00BCD4),
    Color(0xFF00FF41),
    Color(0xFFE040FB),
  ];
}

/// Clip with a 45° chamfer on the bottom-right (spectral “blade” corner).
Path spectralAngledBrPath(Size size, {double cut = SpectralHudTokens.angledCut}) {
  final w = size.width;
  final h = size.height;
  final c = cut.clamp(0.0, math.min(w, h) / 2);
  return Path()
    ..moveTo(0, 0)
    ..lineTo(w, 0)
    ..lineTo(w, h - c)
    ..lineTo(w - c, h)
    ..lineTo(0, h)
    ..close();
}

import 'package:flutter/material.dart';

/// Shared motion tokens — one rhythm across Study, Home, and polish surfaces.
abstract final class NexusMotion {
  /// Level bar, card flip, translation reveal — primary UI cadence.
  static const Duration layout = Duration(milliseconds: 320);

  /// Symmetric easing for flips and two-way transitions.
  static const Curve layoutSymmetric = Curves.easeInOutCubic;

  /// One-way easing for progress fills and entrances.
  static const Curve layoutEntrance = Curves.easeOutCubic;

  /// List selection, small state toggles — snappier than [layout].
  static const Duration interaction = Duration(milliseconds: 180);
  static const Curve interactionCurve = Curves.easeOutCubic;

  /// Pause after glitch / feedback before advancing queue.
  static const Duration feedbackHold = Duration(milliseconds: 300);

  /// Answer underline ambience while typing.
  static const Duration pulseCycle = Duration(milliseconds: 1400);
  static const Curve pulseCurve = Curves.easeInOut;

  /// OS / platform **reduced motion** or accessibility setting (not [NexusSettings.effectsEnabled]).
  ///
  /// Use to skip decorative timelines, glow, and orbital particles while keeping functional UI.
  static bool preferStaticMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

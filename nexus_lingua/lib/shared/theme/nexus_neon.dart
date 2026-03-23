import 'package:flutter/material.dart';

/// Tiered outer glow for neon UI (plan UI-G). Prefer over ad-hoc [BoxShadow] stacks.
///
/// Tie motion-heavy tiers to [NexusSettings.effectsEnabled] at call sites.
enum NexusNeonTier {
  /// No extra glow.
  rest,

  /// Hovered / secondary emphasis.
  emphasis,

  /// Selected row, primary control.
  active,
}

/// Shared neon shadow presets — uses [ColorScheme.primary] unless [accent] is set.
abstract final class NexusNeon {
  static List<BoxShadow> shadows(
    BuildContext context,
    NexusNeonTier tier, {
    Color? accent,
  }) {
    final c = accent ?? Theme.of(context).colorScheme.primary;
    return switch (tier) {
      NexusNeonTier.rest => const [],
      NexusNeonTier.emphasis => [
          BoxShadow(
            color: c.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      NexusNeonTier.active => [
          BoxShadow(
            color: c.withValues(alpha: 0.26),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: c.withValues(alpha: 0.1),
            blurRadius: 22,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
    };
  }
}

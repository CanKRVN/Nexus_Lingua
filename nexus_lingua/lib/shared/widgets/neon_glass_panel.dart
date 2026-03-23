import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted “glass” panel with a soft neon glow on the border.
///
/// When to use vs [NexusGlass] / [nexusPanelDecoration]: see file-level comment on
/// [nexusPanelDecoration] in `lib/shared/theme/nexus_surfaces.dart`.
class NeonGlassPanel extends StatelessWidget {
  /// Creates a foggy glass surface with [accentBorder] glow.
  const NeonGlassPanel({
    super.key,
    required this.accentBorder,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 12,
  });

  /// Primary neon for border highlight and outer glow.
  final Color accentBorder;

  final Widget child;

  final EdgeInsetsGeometry padding;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: accentBorder.withValues(alpha: 0.42),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: accentBorder.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: -1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(
                color: accentBorder.withValues(alpha: 0.82),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  AppColors.backgroundPrimary.withValues(alpha: 0.55),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

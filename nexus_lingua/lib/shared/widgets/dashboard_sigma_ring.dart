import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative gradient arc for ΣS (plan UI-G — prototype before chart packages).
class DashboardSigmaRing extends StatelessWidget {
  /// Creates a normalized ring for total stability.
  const DashboardSigmaRing({
    super.key,
    required this.sumS,
    this.size = 76,
    this.normalizeBy = 4000,
  });

  final double sumS;
  final double size;

  /// Values above this saturate the ring at 100%.
  final double normalizeBy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final t = normalizeBy <= 0 ? 0.0 : (sumS / normalizeBy).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SigmaRingPainter(
          progress: t,
          primary: scheme.primary,
          secondary: ex.secondaryAccent,
        ),
      ),
    );
  }
}

class _SigmaRingPainter extends CustomPainter {
  _SigmaRingPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);
    const stroke = 5.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = primary.withValues(alpha: 0.12);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, track);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final grad = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweep,
      colors: [
        primary.withValues(alpha: 0.35),
        primary,
        secondary,
      ],
      stops: const [0, 0.55, 1],
      transform: GradientRotation(-math.pi / 2),
    );

    final fore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = grad.createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false, fore);
  }

  @override
  bool shouldRepaint(covariant _SigmaRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}

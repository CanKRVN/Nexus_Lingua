import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mastery_badge.dart';

/// Lightweight tier mix ring (no [BackdropFilter]) — UI-G+ dashboard polish.
class DashboardTierDonut extends StatelessWidget {
  /// Creates a donut from per-tier card counts.
  const DashboardTierDonut({
    super.key,
    required this.buckets,
    this.size = 88,
    this.strokeWidth = 10,
  });

  final Map<MasteryTier, int> buckets;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TierDonutPainter(
          buckets: buckets,
          strokeWidth: strokeWidth,
          track: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _TierDonutPainter extends CustomPainter {
  _TierDonutPainter({
    required this.buckets,
    required this.strokeWidth,
    required this.track,
  });

  final Map<MasteryTier, int> buckets;
  final double strokeWidth;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    var total = 0;
    for (final t in MasteryTier.values) {
      total += buckets[t] ?? 0;
    }
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final tier in MasteryTier.values) {
      final n = buckets[tier] ?? 0;
      if (n <= 0) continue;
      final sweep = 2 * math.pi * (n / total);
      final col = masteryTierStyle(tier).$2;
      final seg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = col.withValues(alpha: 0.92);
      canvas.drawArc(rect, start, sweep, false, seg);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TierDonutPainter oldDelegate) => true;
}

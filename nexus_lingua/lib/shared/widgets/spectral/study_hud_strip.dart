import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top study HUD: session time + progress arc (left), due + tier (right).
class StudyHudStrip extends StatelessWidget {
  /// Creates the active HUD header row.
  const StudyHudStrip({
    super.key,
    required this.elapsed,
    required this.sessionProgress,
    required this.dueRemaining,
    required this.tierLabel,
  });

  final Duration elapsed;
  final double sessionProgress;
  final int dueRemaining;
  final String tierLabel;

  String get _timeLabel {
    final m = elapsed.inMinutes;
    final s = elapsed.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mono = GoogleFonts.jetBrainsMono;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CustomPaint(
                    painter: _SessionArcPainter(
                      progress: sessionProgress,
                      color: scheme.primary,
                      track: scheme.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SESSION',
                      style: mono(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _timeLabel,
                      style: mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DUE',
                style: mono(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$dueRemaining',
                style: mono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'TIER',
                style: mono(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                tierLabel.toUpperCase(),
                style: mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionArcPainter extends CustomPainter {
  _SessionArcPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 3;
    const stroke = 4.0;
    final rect = Rect.fromCircle(center: c, radius: r);

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glow);

    final fore = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fore);
  }

  @override
  bool shouldRepaint(covariant _SessionArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

import 'dart:math' as math;
import 'dart:ui' show BlurStyle, MaskFilter, PathMetric;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../theme/nexus_motion.dart';
import 'spectral/spectral_hud_tokens.dart';

/// ~2π/3 rad/s — one full turn ≈ 3s (matches former beam controller duration).
double get _defaultBeamRadiansPerSecond => 2 * math.pi / 3;

/// Bright segment length as a fraction of the rounded-rect perimeter (~5–10%).
const double _beamLengthFraction = 0.075;

const double _trackStrokeWidth = 2.0;
const double _beamStrokeWidth = 3.5;

/// Builds a [Path] for the bright beam: [beamLen] distance along [metric] from [startDist].
Path _beamSegmentPath(PathMetric metric, double startDist, double beamLen) {
  final len = metric.length;
  if (len <= 0 || beamLen <= 0) return Path();
  final s = startDist % len;
  final e = s + beamLen;
  final path = Path();
  if (e <= len) {
    path.addPath(metric.extractPath(s, e), Offset.zero);
  } else {
    path.addPath(metric.extractPath(s, len), Offset.zero);
    path.addPath(metric.extractPath(0, e - len), Offset.zero);
  }
  return path;
}

/// Dim full track + short green highlight that travels the perimeter (no full sweep).
class RotatingGreenBorderPainter extends CustomPainter {
  /// Creates a painter; [phaseRad] advances the beam along the path (2π = one lap).
  RotatingGreenBorderPainter({
    required ValueListenable<double> phaseRad,
    required this.borderRadius,
    required this.trackDim,
    required this.glowColor,
    required this.beamColor,
    this.spectralOutline = false,
  })  : _phaseRad = phaseRad,
        super(repaint: phaseRad);

  final ValueListenable<double> _phaseRad;
  final double borderRadius;
  final Color trackDim;
  final Color glowColor;
  final Color beamColor;

  /// When true, beam follows [spectralAngledBrPath] (same outline as [StudyMasteryCard]).
  final bool spectralOutline;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outline;
    if (spectralOutline) {
      outline = spectralAngledBrPath(
        size,
        cut: SpectralHudTokens.angledCut,
      );
    } else {
      final rrect = RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(borderRadius),
      );
      outline = Path()..addRRect(rrect);
    }

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trackStrokeWidth
      ..strokeJoin = StrokeJoin.round
      ..color = trackDim;

    canvas.drawPath(outline, trackPaint);
    for (final metric in outline.computeMetrics(forceClosed: true)) {
      final len = metric.length;
      if (len <= 0) break;

      final u = (_phaseRad.value % (2 * math.pi)) / (2 * math.pi);
      final startDist = u * len;
      final beamLen = len * _beamLengthFraction;

      final beamPath = _beamSegmentPath(metric, startDist, beamLen);

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _beamStrokeWidth + 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final beamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _beamStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = beamColor;

      canvas.drawPath(beamPath, glowPaint);
      canvas.drawPath(beamPath, beamPaint);
      break;
    }
  }

  @override
  bool shouldRepaint(covariant RotatingGreenBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.spectralOutline != spectralOutline ||
        oldDelegate.trackDim != trackDim ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.beamColor != beamColor;
  }
}

/// Wraps [child] with a continuously rotating green beam on the border while
/// [active] is true (no 0→1 loop seam).
class RotatingGreenBorder extends StatefulWidget {
  /// Creates an animated border overlay.
  const RotatingGreenBorder({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = 12,
    this.radiansPerSecond,
    this.spectralOutline = false,
  });

  /// When false, only [child] is shown.
  final bool active;

  final Widget child;

  final double borderRadius;

  /// Angular speed of the beam; default ~one turn every 3s.
  final double? radiansPerSecond;

  /// Match [StudyMasteryCard] chamfer so the beam shares one silhouette with the glass.
  final bool spectralOutline;

  @override
  State<RotatingGreenBorder> createState() => _RotatingGreenBorderState();
}

class _RotatingGreenBorderState extends State<RotatingGreenBorder>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _phaseRad = ValueNotifier<double>(0);
  Duration? _lastElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.active) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant RotatingGreenBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _lastElapsed = null;
      _ticker.start();
    } else if (!widget.active && oldWidget.active) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed != null) {
      final dt = (elapsed - _lastElapsed!).inMicroseconds / 1e6;
      _phaseRad.value +=
          dt * (widget.radiansPerSecond ?? _defaultBeamRadiansPerSecond);
    }
    _lastElapsed = elapsed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NexusMotion.preferStaticMotion(context)) {
      _ticker.stop();
    } else if (widget.active && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phaseRad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    if (NexusMotion.preferStaticMotion(context)) return widget.child;
    final success = Theme.of(context).colorScheme.tertiary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: RotatingGreenBorderPainter(
                phaseRad: _phaseRad,
                borderRadius: widget.borderRadius,
                spectralOutline: widget.spectralOutline,
                trackDim: success.withValues(alpha: 0.14),
                glowColor: success.withValues(alpha: 0.4),
                beamColor: success,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

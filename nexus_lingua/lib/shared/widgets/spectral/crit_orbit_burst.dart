import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/nexus_motion.dart';
import 'spectral_hud_tokens.dart';

/// Neon particles orbit [child] briefly (Crit! exact match).
class CritOrbitBurst extends StatefulWidget {
  /// Wraps [child] with a short orbital particle burst.
  const CritOrbitBurst({
    super.key,
    required this.child,
    this.active = true,
  });

  final Widget child;
  final bool active;

  @override
  State<CritOrbitBurst> createState() => _CritOrbitBurstState();
}

class _CritOrbitBurstState extends State<CritOrbitBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (NexusMotion.preferStaticMotion(context)) return;
      if (widget.active) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant CritOrbitBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (NexusMotion.preferStaticMotion(context)) return;
    if (widget.active && !oldWidget.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    if (NexusMotion.preferStaticMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OrbitParticlesPainter(
                    t: _c.value,
                    colors: SpectralHudTokens.critParticleColors,
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _OrbitParticlesPainter extends CustomPainter {
  _OrbitParticlesPainter({
    required this.t,
    required this.colors,
  });

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const n = 14;
    final baseR = math.min(size.width, size.height) * 0.42;
    final fade = (1 - Curves.easeOut.transform(t)).clamp(0.0, 1.0);

    for (var i = 0; i < n; i++) {
      final phase = i / n;
      final ang = phase * 2 * math.pi + t * 3 * math.pi;
      final wobble = 0.85 + 0.15 * math.sin(t * math.pi * 4 + i);
      final r = baseR * wobble;
      final p = Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang));
      final col = colors[i % colors.length].withValues(alpha: 0.35 * fade);
      final paint = Paint()
        ..color = col
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(p, 2.2 + (1 - t) * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitParticlesPainter oldDelegate) =>
      oldDelegate.t != t;
}

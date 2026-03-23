import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fsrs_rating_row.dart';
import 'spectral_hud_tokens.dart';

/// Octagonal hit target for FSRS ratings (compact study HUD).
class FsrsHudNodes extends StatefulWidget {
  /// Creates four geometric nodes: Again → Easy.
  const FsrsHudNodes({
    super.key,
    required this.onRated,
    this.busy = false,
    this.schedulePreviewLines,
    this.displayStyle = RatingDisplayStyle.labels,
  });

  final ValueChanged<int> onRated;
  final bool busy;
  final List<String>? schedulePreviewLines;
  final RatingDisplayStyle displayStyle;

  @override
  State<FsrsHudNodes> createState() => _FsrsHudNodesState();
}

class _FsrsHudNodesState extends State<FsrsHudNodes> {
  int? _hovered;

  static const _labels = ['Again', 'Hard', 'Good', 'Easy'];
  static const _symbols = ['✕', '↑', '↑↑', '↑↑↑'];
  static const _ratings = [1, 2, 3, 4];
  static const _glowColors = [
    SpectralHudTokens.nodeAgain,
    SpectralHudTokens.nodeHard,
    SpectralHudTokens.nodeGood,
    SpectralHudTokens.nodeEasy,
  ];

  @override
  Widget build(BuildContext context) {
    final previews = widget.schedulePreviewLines;
    assert(
      previews == null || previews.length == 4,
      'schedulePreviewLines must be null or length 4',
    );
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) {
            final active = _hovered == i && !widget.busy;
            final glow = _glowColors[i];
            return _HudOctagonNode(
              label: _labels[i],
              symbol: _symbols[i],
              rating: _ratings[i],
              glowColor: glow,
              active: active,
              enabled: !widget.busy,
              preview: previews != null ? previews[i] : null,
              scheme: scheme,
              displayStyle: widget.displayStyle,
              onHover: (v) => setState(() => _hovered = v ? i : null),
              onTap: () {
                if (!widget.busy) widget.onRated(_ratings[i]);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _HudOctagonNode extends StatelessWidget {
  const _HudOctagonNode({
    required this.label,
    required this.symbol,
    required this.rating,
    required this.glowColor,
    required this.active,
    required this.enabled,
    required this.preview,
    required this.scheme,
    required this.displayStyle,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final String symbol;
  final int rating;
  final Color glowColor;
  final bool active;
  final bool enabled;
  final String? preview;
  final ColorScheme scheme;
  final RatingDisplayStyle displayStyle;
  final void Function(bool) onHover;
  final VoidCallback onTap;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final showPreview =
        displayStyle != RatingDisplayStyle.colorsOnly &&
            preview != null &&
            preview!.isNotEmpty;
    final showSymbol = displayStyle != RatingDisplayStyle.colorsOnly;
    final showLabel = displayStyle == RatingDisplayStyle.labels;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          canRequestFocus: enabled,
          focusColor: glowColor.withValues(alpha: 0.28),
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          customBorder: _OctagonBorder(),
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPreview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary.withValues(
                          alpha: enabled ? 0.75 : 0.35,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: _size,
                  height: _size,
                  child: CustomPaint(
                    painter: _OctagonGlowPainter(
                      glowColor: glowColor,
                      active: active && enabled,
                      fillWhenColorsOnly:
                          displayStyle == RatingDisplayStyle.colorsOnly,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showSymbol)
                            Text(
                              symbol,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: enabled
                                    ? glowColor.withValues(
                                        alpha: active ? 1 : 0.55,
                                      )
                                    : glowColor.withValues(alpha: 0.25),
                              ),
                            ),
                          if (showLabel)
                            Text(
                              label,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: enabled ? 0.7 : 0.35),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonBorder extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _octagonPath(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _octagonPath(rect);

  static Path _octagonPath(Rect rect) {
    final c = Offset(rect.center.dx, rect.center.dy);
    final r = math.min(rect.width, rect.height) / 2 * 0.92;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class _OctagonGlowPainter extends CustomPainter {
  _OctagonGlowPainter({
    required this.glowColor,
    required this.active,
    this.fillWhenColorsOnly = false,
  });

  final Color glowColor;
  final bool active;
  final bool fillWhenColorsOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 * 0.88;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    if (fillWhenColorsOnly) {
      final fill = Paint()
        ..color = glowColor.withValues(alpha: active ? 0.55 : 0.28);
      canvas.drawPath(path, fill);
    }

    if (active) {
      final glow = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(path, glow);
      final mid = Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, mid);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.2 : 0.8
      ..color = active
          ? glowColor.withValues(alpha: 0.95)
          : glowColor.withValues(alpha: fillWhenColorsOnly ? 0.35 : 0.12);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _OctagonGlowPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.fillWhenColorsOnly != fillWhenColorsOnly;
}

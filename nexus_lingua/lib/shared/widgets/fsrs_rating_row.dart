import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact rating row presentation (PRD §8.5).
enum RatingDisplayStyle {
  labels,
  symbols,
  colorsOnly,
}

/// Four FSRS rating buttons (compact study mode): Again → Easy.
///
/// Minimum tap height 48. Crit uses [ColorScheme.tertiary] (success).
class FsrsRatingRow extends StatelessWidget {
  /// Creates a row of rating actions.
  const FsrsRatingRow({
    super.key,
    required this.onRated,
    this.busy = false,
    this.displayStyle = RatingDisplayStyle.labels,
    this.schedulePreviewLines,
  });

  /// Called with FSRS rating 1..4 when the user taps a button.
  final ValueChanged<int> onRated;

  /// When true, buttons are disabled (e.g. while saving).
  final bool busy;

  /// Label / symbol / color-only presentation.
  final RatingDisplayStyle displayStyle;

  /// Optional lines above each button (Miss→Crit), from FSRS preview due dates.
  final List<String>? schedulePreviewLines;

  static const double _minTap = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final previews = schedulePreviewLines;
    assert(
      previews == null || previews.length == 4,
      'schedulePreviewLines must be null or length 4',
    );
    return Row(
      children: [
        Expanded(
          child: _RatingCell(
            label: 'Miss',
            subtitle: 'Again',
            symbol: '✕',
            color: scheme.error,
            rating: 1,
            onRated: onRated,
            enabled: !busy,
            displayStyle: displayStyle,
            schedulePreview: previews != null ? previews[0] : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Hard',
            subtitle: 'Hard',
            symbol: '↑',
            color: ex.feedbackHard,
            rating: 2,
            onRated: onRated,
            enabled: !busy,
            displayStyle: displayStyle,
            schedulePreview: previews != null ? previews[1] : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Hit',
            subtitle: 'Good',
            symbol: '↑↑',
            color: ex.feedbackHit,
            rating: 3,
            onRated: onRated,
            enabled: !busy,
            displayStyle: displayStyle,
            schedulePreview: previews != null ? previews[2] : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Crit!',
            subtitle: 'Easy',
            symbol: '↑↑↑',
            color: scheme.tertiary,
            rating: 4,
            onRated: onRated,
            enabled: !busy,
            displayStyle: displayStyle,
            schedulePreview: previews != null ? previews[3] : null,
          ),
        ),
      ],
    );
  }
}

class _RatingCell extends StatelessWidget {
  const _RatingCell({
    required this.label,
    required this.subtitle,
    required this.symbol,
    required this.color,
    required this.rating,
    required this.onRated,
    required this.enabled,
    required this.displayStyle,
    this.schedulePreview,
  });

  final String label;
  final String subtitle;
  final String symbol;
  final Color color;
  final int rating;
  final ValueChanged<int> onRated;
  final bool enabled;
  final RatingDisplayStyle displayStyle;
  final String? schedulePreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final primary = switch (displayStyle) {
      RatingDisplayStyle.labels => label,
      RatingDisplayStyle.symbols => symbol,
      RatingDisplayStyle.colorsOnly => '',
    };
    final showSecondary =
        displayStyle == RatingDisplayStyle.labels && primary.isNotEmpty;
    final previewLine = schedulePreview;
    final minH = (previewLine != null && previewLine.isNotEmpty)
        ? 56.0
        : FsrsRatingRow._minTap;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onRated(rating) : null,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? color : color.withValues(alpha: 0.35),
                width: displayStyle == RatingDisplayStyle.colorsOnly ? 3 : 1,
              ),
              color: displayStyle == RatingDisplayStyle.colorsOnly
                  ? color.withValues(alpha: enabled ? 0.22 : 0.08)
                  : ex.surfaceGlassInput,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (previewLine != null && previewLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        previewLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.nexusMono(
                          9,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary.withValues(
                            alpha: enabled ? 0.85 : 0.4,
                          ),
                        ).copyWith(height: 1.1),
                      ),
                    ),
                  if (primary.isNotEmpty)
                    Text(
                      primary,
                      style: TextStyle(
                        color: enabled ? color : color.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: displayStyle == RatingDisplayStyle.symbols
                            ? 18
                            : 13,
                      ),
                    ),
                  if (showSecondary)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ex.textSubtext.withValues(
                          alpha: enabled ? 1 : 0.45,
                        ),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

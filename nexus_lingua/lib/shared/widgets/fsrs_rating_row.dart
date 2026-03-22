import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Four FSRS rating buttons (compact study mode): Again → Easy.
///
/// Cyber-Minimalist feedback colors (`.cursorrules` §2). Minimum tap height 48.
class FsrsRatingRow extends StatelessWidget {
  /// Creates a row of rating actions.
  const FsrsRatingRow({
    super.key,
    required this.onRated,
    this.busy = false,
  });

  /// Called with FSRS rating 1..4 when the user taps a button.
  final ValueChanged<int> onRated;

  /// When true, buttons are disabled (e.g. while saving).
  final bool busy;

  static const double _minTap = 48;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RatingCell(
            label: 'Miss',
            subtitle: 'Again',
            color: AppColors.feedbackMiss,
            rating: 1,
            onRated: onRated,
            enabled: !busy,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Hard',
            subtitle: 'Hard',
            color: AppColors.feedbackHard,
            rating: 2,
            onRated: onRated,
            enabled: !busy,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Hit',
            subtitle: 'Good',
            color: AppColors.feedbackHit,
            rating: 3,
            onRated: onRated,
            enabled: !busy,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _RatingCell(
            label: 'Crit!',
            subtitle: 'Easy',
            color: AppColors.feedbackCrit,
            rating: 4,
            onRated: onRated,
            enabled: !busy,
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
    required this.color,
    required this.rating,
    required this.onRated,
    required this.enabled,
  });

  final String label;
  final String subtitle;
  final Color color;
  final int rating;
  final ValueChanged<int> onRated;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onRated(rating) : null,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: FsrsRatingRow._minTap),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? color : color.withValues(alpha: 0.35),
              ),
              color: AppColors.surfaceGlass,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled ? color : color.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSubtext.withValues(
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

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// XP bar: `progress = min(S / S_max, 1)` (PRD §7.4).
class XpStabilityBar extends StatelessWidget {
  /// Creates an XP-style stability bar.
  const XpStabilityBar({
    super.key,
    required this.stability,
    this.sMax = 365,
  });

  /// FSRS stability S (days).
  final double stability;

  /// Normalization cap (default 365).
  final double sMax;

  @override
  Widget build(BuildContext context) {
    final progress = (stability / sMax).clamp(0.0, 1.0);
    final dim = AppColors.accentGreen.withValues(alpha: 0.25);
    final bright = AppColors.accentGreen;
    final fill = Color.lerp(dim, bright, progress)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stability (S)',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSubtext,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.textDisabled.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      ],
    );
  }
}

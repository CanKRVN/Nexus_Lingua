import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mastery tier from stability S (PRD §7.4 / `.cursorrules` §4.4).
enum MasteryTier {
  novice,
  apprentice,
  journeyman,
  elite,
  legend,
}

/// Maps stability (days) to [MasteryTier].
MasteryTier masteryTierForStability(double s) {
  if (s < 1) return MasteryTier.novice;
  if (s < 7) return MasteryTier.apprentice;
  if (s < 30) return MasteryTier.journeyman;
  if (s < 120) return MasteryTier.elite;
  return MasteryTier.legend;
}

/// Label + accent color for a tier.
(String label, Color color) masteryTierStyle(MasteryTier t) {
  switch (t) {
    case MasteryTier.novice:
      return ('Novice', AppColors.textSubtext);
    case MasteryTier.apprentice:
      return ('Apprentice', AppColors.accentCyan);
    case MasteryTier.journeyman:
      return ('Journeyman', AppColors.accentGreen);
    case MasteryTier.elite:
      return ('Elite', AppColors.accentMagenta);
    case MasteryTier.legend:
      return ('Legend', const Color(0xFFFFD700));
  }
}

/// Compact pill showing mastery tier from stability S.
class MasteryBadge extends StatelessWidget {
  /// Creates a badge for the given stability (days).
  const MasteryBadge({super.key, required this.stabilityS});

  /// Current FSRS stability in days.
  final double stabilityS;

  @override
  Widget build(BuildContext context) {
    final tier = masteryTierForStability(stabilityS);
    final (label, color) = masteryTierStyle(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
        color: AppColors.surfaceGlass,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

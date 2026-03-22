import 'package:flutter/material.dart';

import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../theme/app_theme.dart';
import 'mastery_badge.dart';
import 'xp_stability_bar.dart';

/// Cyber-Minimalist flashcard: lemma, translation, metadata grid, XP bar, badge.
///
/// Stateless; gender drives neon border (`.cursorrules` §2).
class FlashcardWidget extends StatelessWidget {
  /// Creates a flashcard for [card] under [profile].
  const FlashcardWidget({
    super.key,
    required this.card,
    required this.profile,
    this.sMax = 365,
  });

  /// Card data.
  final WordCard card;

  /// Active language profile (feature checklist).
  final LanguageProfile profile;

  /// XP bar normalization (default 365).
  final double sMax;

  Color _borderColor() {
    final g = card.metadata['gender'];
    if (g is! String) return AppColors.borderNeutral;
    switch (g.toLowerCase()) {
      case 'masculine':
        return AppColors.accentCyan;
      case 'feminine':
        return AppColors.accentMagenta;
      case 'neuter':
        return AppColors.accentGreen;
      default:
        return AppColors.borderNeutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = _borderColor();
    final metaKeys = profile.features
        .where((k) => card.metadata.containsKey(k))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.lemma,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBody,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            card.translation,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSubtext,
                ),
          ),
          if (metaKeys.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Details',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.accentCyan,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metaKeys.map((key) {
                final v = card.metadata[key];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '$key: $v',
                    style: const TextStyle(
                      color: AppColors.textBody,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          XpStabilityBar(stability: card.stability, sMax: sMax),
          const SizedBox(height: 12),
          Row(
            children: [
              MasteryBadge(stabilityS: card.stability),
              const Spacer(),
              Text(
                'D=${card.difficulty.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: AppColors.textSubtext,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

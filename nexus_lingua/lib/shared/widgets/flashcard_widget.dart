import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../theme/app_theme.dart';
import 'mastery_badge.dart';
import 'neon_glass_panel.dart';
import 'xp_stability_bar.dart';

/// Cyber-Minimalist flashcard: stacked glass panels for prompt, metadata, mastery.
///
/// Stateless; gender drives neon border on each panel (`.cursorrules` §2).
/// Target line uses [WordCard.targetSurface] (article + lemma when set).
///
/// When [layoutHeight] is set (e.g. study screen), panels expand to fill the area.
class FlashcardWidget extends StatelessWidget {
  /// Creates a flashcard for [card] under [profile].
  const FlashcardWidget({
    super.key,
    required this.card,
    required this.profile,
    this.sMax = 365,
    this.layoutHeight,
    this.layoutWidth,
  });

  /// Card data.
  final WordCard card;

  /// Active language profile (feature checklist).
  final LanguageProfile profile;

  /// XP bar normalization (default 365).
  final double sMax;

  /// When non-null with finite height, column uses [Expanded] to fill study area.
  final double? layoutHeight;

  /// Max width when filling layout (optional).
  final double? layoutWidth;

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

  bool _metaValuePresent(String key) {
    if (!card.metadata.containsKey(key)) return false;
    final v = card.metadata[key];
    if (v == null) return false;
    if (v is bool) return true;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  List<String> _keysForSide(List<String> sideFeatures) {
    return sideFeatures
        .where((k) => k != 'case_sensitive')
        .where(_metaValuePresent)
        .toList();
  }

  Widget _metaChip(Color border, String key) {
    final v = card.metadata[key];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$key: $v',
        style: const TextStyle(color: AppColors.textBody, fontSize: 13),
      ),
    );
  }

  Widget _detailsContent(BuildContext context, Color border) {
    final targetKeys = _keysForSide(profile.features);
    final knownKeys = _keysForSide(profile.featuresKnown);
    final knownLabel = profile.knownLanguage.trim().isEmpty
        ? 'Known language'
        : profile.knownLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (targetKeys.isNotEmpty) ...[
          Text(
            'Target (${profile.language})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: targetKeys.map((k) => _metaChip(border, k)).toList(),
          ),
        ],
        if (targetKeys.isNotEmpty && knownKeys.isNotEmpty)
          const SizedBox(height: 16),
        if (knownKeys.isNotEmpty) ...[
          Text(
            'Known ($knownLabel)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentMagenta,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: knownKeys.map((k) => _metaChip(border, k)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _lemmaTranslationColumn(
    BuildContext context,
    TextStyle targetStyle,
    TextStyle translationStyle,
  ) {
    final knownLabel = profile.knownLanguage.trim().isEmpty
        ? 'Known gloss'
        : profile.knownLanguage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.targetSurface,
          textAlign: TextAlign.center,
          style: targetStyle,
        ),
        const SizedBox(height: 10),
        Text(
          knownLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSubtext,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          card.translation,
          textAlign: TextAlign.center,
          style: translationStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = _borderColor();
    final targetKeys = _keysForSide(profile.features);
    final knownKeys = _keysForSide(profile.featuresKnown);
    final hasMetaPanel = targetKeys.isNotEmpty || knownKeys.isNotEmpty;

    final targetStyle = GoogleFonts.jetBrainsMono(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.bold,
      color: AppColors.textBody,
    );
    final translationStyle = GoogleFonts.inter(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.textSubtext,
    );

    final metaSection =
        hasMetaPanel ? _detailsContent(context, border) : null;

    final masterySection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        XpStabilityBar(stability: card.stability, sMax: sMax),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
    );

    final fill = layoutHeight != null &&
        layoutHeight!.isFinite &&
        layoutHeight! > 0;

    if (!fill) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          NeonGlassPanel(
            accentBorder: border,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: _lemmaTranslationColumn(
              context,
              targetStyle,
              translationStyle,
            ),
          ),
          if (hasMetaPanel) ...[
            const SizedBox(height: 12),
            NeonGlassPanel(
              accentBorder: border,
              child: metaSection!,
            ),
          ],
          const SizedBox(height: 12),
          NeonGlassPanel(
            accentBorder: border,
            child: masterySection,
          ),
        ],
      );
    }

    final h = layoutHeight!;
    final w = layoutWidth;

    final topFlex = hasMetaPanel ? 46 : 58;
    final midFlex = hasMetaPanel ? 26 : 0;
    final botFlex = hasMetaPanel ? 28 : 42;

    return SizedBox(
      height: h,
      width: w ?? double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: topFlex,
            child: NeonGlassPanel(
              accentBorder: border,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: SingleChildScrollView(
                  child: _lemmaTranslationColumn(
                    context,
                    targetStyle,
                    translationStyle,
                  ),
                ),
              ),
            ),
          ),
          if (hasMetaPanel) ...[
            const SizedBox(height: 12),
            Expanded(
              flex: midFlex,
              child: NeonGlassPanel(
                accentBorder: border,
                child: SingleChildScrollView(
                  child: metaSection!,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            flex: botFlex,
            child: NeonGlassPanel(
              accentBorder: border,
              child: SingleChildScrollView(
                child: masterySection,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

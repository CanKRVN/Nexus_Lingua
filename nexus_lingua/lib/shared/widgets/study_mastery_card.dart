import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_card.dart';
import '../theme/app_theme.dart';
import '../theme/nexus_motion.dart';
import 'spectral/spectral_hud_tokens.dart';

/// HUD shell for prompt — frosted glass, no heavy shadows (Spectral protocol).
BoxDecoration studyHeroDecoration(
  BuildContext context, {
  bool glitchBorder = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final fill = context.nexusExtras.glassFill;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(18),
    color: Color.alphaBlend(
      scheme.primary.withValues(alpha: SpectralHudTokens.overlayOpacity(context)),
      fill,
    ),
    border: glitchBorder
        ? Border.all(color: scheme.error, width: 2)
        : Border.all(
            color: scheme.primary.withValues(alpha: 0.05),
            width: 1,
          ),
  );
}

class _SpectralBrClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      spectralAngledBrPath(size, cut: SpectralHudTokens.angledCut);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Single central card: angled glass HUD, lemma + translation, S/D/R tags.
class StudyMasteryCard extends StatefulWidget {
  /// Creates the study mastery hero.
  const StudyMasteryCard({
    super.key,
    required this.card,
    this.glitchBorder = false,
    this.animateTranslationReveal = true,
  });

  final WordCard card;
  final bool glitchBorder;
  final bool animateTranslationReveal;

  @override
  State<StudyMasteryCard> createState() => _StudyMasteryCardState();
}

class _StudyMasteryCardState extends State<StudyMasteryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (NexusMotion.preferStaticMotion(context)) {
      _pulse
        ..stop()
        ..value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    final fill = context.nexusExtras.glassFill;
    final overlayA = SpectralHudTokens.overlayOpacity(context);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final halo = 0.04 +
            0.05 *
                (0.5 +
                    0.5 *
                        math.sin(
                          _pulse.value * 2 * math.pi,
                        ));
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: halo),
                blurRadius: 22,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipPath(
            clipper: _SpectralBrClipper(),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: SpectralHudTokens.blurSigma,
                sigmaY: SpectralHudTokens.blurSigma,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    scheme.primary.withValues(alpha: overlayA),
                    fill,
                  ),
                  border: widget.glitchBorder
                      ? Border.all(color: scheme.error, width: 2)
                      : Border.all(
                          color: scheme.primary.withValues(alpha: 0.06),
                          width: 1,
                        ),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.card.targetSurface,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: context.nexusInterContent(
                                56,
                                fontWeight: FontWeight.w700,
                              ).copyWith(
                                height: 1.05,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          widget.animateTranslationReveal
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: NexusMotion.layout,
                                  curve: NexusMotion.layoutEntrance,
                                  builder: (context, t, child) {
                                    return Transform.translate(
                                      offset: Offset(0, (1 - t) * 10),
                                      child: Opacity(opacity: t, child: child),
                                    );
                                  },
                                  child: Text(
                                    widget.card.translation,
                                    textAlign: TextAlign.center,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.nexusInterContent(20).copyWith(
                                      height: 1.35,
                                      color: onSurface.withValues(alpha: 0.55),
                                    ),
                                  ),
                                )
                              : Text(
                                  widget.card.translation,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.nexusInterContent(20).copyWith(
                                    height: 1.35,
                                    color: onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 10,
                      child: _hudTag(
                        'S ${widget.card.stability.toStringAsFixed(2)}',
                        context,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 10,
                      child: _hudTag(
                        'D ${widget.card.difficulty.toStringAsFixed(2)}',
                        context,
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _hudTag(
                        'R ${widget.card.retrievability.toStringAsFixed(3)}',
                        context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _hudTag(String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

/// Pre-reveal prompt only — frosted glass strip.
class StudyPromptHero extends StatelessWidget {
  const StudyPromptHero({
    super.key,
    required this.prompt,
    this.glitchBorder = false,
  });

  final String prompt;
  final bool glitchBorder;

  @override
  Widget build(BuildContext context) {
    final fill = context.nexusExtras.glassFill;
    final scheme = Theme.of(context).colorScheme;
    final overlayA = SpectralHudTokens.overlayOpacity(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: SpectralHudTokens.blurSigma,
          sigmaY: SpectralHudTokens.blurSigma,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Color.alphaBlend(
              scheme.primary.withValues(alpha: overlayA),
              fill,
            ),
            border: glitchBorder
                ? Border.all(color: scheme.error, width: 2)
                : Border.all(
                    color: scheme.primary.withValues(alpha: 0.05),
                    width: 1,
                  ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                prompt,
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: context
                    .nexusInterContent(64, fontWeight: FontWeight.w700)
                    .copyWith(
                  height: 1.06,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

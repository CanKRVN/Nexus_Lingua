import 'package:flutter/material.dart';

import '../widgets/spectral/spectral_hud_tokens.dart';
import 'app_theme.dart';

/// **Glass / panel patterns** (keep in sync with `.cursorrules` §2 and UI agent plan):
/// - [nexusPanelDecoration] — **flat** tiles and list rows: tint + hairline, **no**
///   [BackdropFilter]. Prefer for **long lists** and web performance.
/// - [NexusGlass] (`app_theme.dart`) — **frosted** blocks: blur σ 20 + primary tint;
///   settings sections, dashboard tiles, moderate chrome.
/// - [NeonGlassPanel] — **emphasis** surfaces: stronger border + glow + blur; use
///   **sparingly** and avoid stacking many simultaneous filters.
BoxDecoration nexusPanelDecoration(
  BuildContext context, {
  bool accentMagenta = false,
  double borderRadius = 16,
  bool highlighted = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  final ex = context.nexusExtras;
  final edge = accentMagenta
      ? ex.secondaryAccent.withValues(alpha: highlighted ? 0.18 : 0.11)
      : scheme.primary.withValues(alpha: highlighted ? 0.14 : 0.065);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    color: Color.alphaBlend(
      scheme.primary.withValues(alpha: SpectralHudTokens.overlayOpacity(context)),
      ex.glassFill,
    ),
    border: Border.all(color: edge, width: 1),
  );
}

/// Section title style aligned with home / study chrome.
TextStyle? nexusSectionTitleStyle(
  BuildContext context, {
  Color? color,
}) {
  return Theme.of(context).textTheme.titleSmall?.copyWith(
        color: color ?? Theme.of(context).colorScheme.primary,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      );
}

/// Small-caps style section label (HUD); pairs with [nexusSectionTitleStyle].
class NexusSectionHeader extends StatelessWidget {
  /// Creates a section header line.
  const NexusSectionHeader(
    this.text, {
    super.key,
    this.color,
    this.magentaAccent = false,
  });

  final String text;
  final Color? color;
  final bool magentaAccent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final c = color ??
        (magentaAccent ? ex.secondaryAccent : scheme.primary);
    return Text(
      text.toUpperCase(),
      style: nexusSectionTitleStyle(context, color: c)?.copyWith(
            fontSize: 11,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

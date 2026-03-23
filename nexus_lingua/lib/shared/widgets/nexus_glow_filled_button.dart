import 'package:flutter/material.dart';

import '../../core/settings/nexus_settings.dart';
import '../theme/nexus_motion.dart';
import '../theme/nexus_neon.dart';

/// Matches default M3 filled button corner geometry for outer glow alignment.
const double kNexusGlowFilledButtonRadius = 20;

Widget _glowWrap(BuildContext context, Widget button) {
  if (!context.nexusSettings.effectsEnabled) return button;
  if (NexusMotion.preferStaticMotion(context)) return button;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(kNexusGlowFilledButtonRadius),
      boxShadow: NexusNeon.shadows(context, NexusNeonTier.emphasis),
    ),
    child: button,
  );
}

/// [FilledButton] with optional [NexusNeon] emphasis glow when
/// [NexusSettings.effectsEnabled] is true.
class NexusGlowFilledButton extends StatelessWidget {
  /// Creates a primary filled button with optional glow.
  const NexusGlowFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusStyle = ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: scheme.primary, width: 2);
        }
        return BorderSide.none;
      }),
    );
    final merged = style == null ? focusStyle : focusStyle.merge(style!);
    final button = FilledButton(
      onPressed: onPressed,
      style: merged,
      child: child,
    );
    return _glowWrap(context, button);
  }
}

/// [FilledButton.icon] with optional glow (see [NexusGlowFilledButton]).
class NexusGlowFilledButtonIcon extends StatelessWidget {
  /// Creates an icon + label filled button with optional glow.
  const NexusGlowFilledButtonIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusStyle = ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: scheme.primary, width: 2);
        }
        return BorderSide.none;
      }),
    );
    final merged = style == null ? focusStyle : focusStyle.merge(style!);
    final button = FilledButton.icon(
      onPressed: onPressed,
      style: merged,
      icon: icon,
      label: label,
    );
    return _glowWrap(context, button);
  }
}

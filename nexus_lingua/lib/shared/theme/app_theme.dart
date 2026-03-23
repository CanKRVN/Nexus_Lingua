import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/spectral/spectral_hud_tokens.dart';
import 'theme_constants.dart';

/// Backward-compatible color aliases used across existing widgets.
abstract final class AppColors {
  static const Color backgroundPrimary = NexusPaletteDark.background;
  static const Color surfaceStudyWell = Color(0xFF121212);
  static const Color accentCyan = NexusPaletteDark.primary;
  static const Color accentMagenta = Color(0xFFE91E8C);
  static const Color accentGreen = NexusPaletteDark.success;
  static const Color textBody = Color(0xFFE0E0E0);
  static const Color textSubtext = Color(0xFF777777);
  static const Color textDisabled = Color(0xFF444444);
  static const Color borderNeutral = Color(0xFF555555);
  static const Color surfaceGlass = Color(0x0DFFFFFF);
  static const Color feedbackCrit = NexusPaletteDark.success;
  static const Color feedbackHit = Color(0xFF69F0AE);
  static const Color feedbackHard = Color(0xFFFFD740);
  static const Color feedbackMiss = NexusPaletteDark.error;
}

/// Centralized Nexus light/dark [ThemeData] factories.
abstract final class AppTheme {
  /// Dark palette (default).
  static ThemeData get dark => _buildDark();

  /// Light palette.
  static ThemeData get light => _buildLight();
}

/// Semantic tokens beyond [ColorScheme] (feedback, glass, wells).
@immutable
class NexusExtras extends ThemeExtension<NexusExtras> {
  /// Creates extras; prefer [NexusExtras.dark] / [NexusExtras.light].
  const NexusExtras({
    required this.feedbackHard,
    required this.feedbackHit,
    required this.glassFill,
    required this.drawerGlassFill,
    required this.borderNeutral,
    required this.textSubtext,
    required this.textDisabled,
    required this.surfaceStudyWell,
    required this.surfaceGlassInput,
    required this.secondaryAccent,
    required this.cardShadows,
  });

  final Color feedbackHard;
  final Color feedbackHit;
  final Color glassFill;
  final Color drawerGlassFill;
  final Color borderNeutral;
  final Color textSubtext;
  final Color textDisabled;
  final Color surfaceStudyWell;
  final Color surfaceGlassInput;
  final Color secondaryAccent;
  final List<BoxShadow> cardShadows;

  static final NexusExtras dark = NexusExtras(
    feedbackHard: const Color(0xFFFFD740),
    feedbackHit: const Color(0xFF69F0AE),
    glassFill: const Color(0x590D0D0D),
    drawerGlassFill: const Color(0x520D0D0D),
    borderNeutral: const Color(0xFF555555),
    textSubtext: const Color(0xFF777777),
    textDisabled: const Color(0xFF444444),
    surfaceStudyWell: const Color(0xFF121212),
    surfaceGlassInput: const Color(0x0DFFFFFF),
    secondaryAccent: const Color(0xFFE91E8C),
    cardShadows: [
      BoxShadow(
        color: NexusPaletteDark.primary.withValues(alpha: 0.1),
        blurRadius: 15,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final NexusExtras light = NexusExtras(
    feedbackHard: const Color(0xFFF9A825),
    feedbackHit: const Color(0xFF43A047),
    glassFill: const Color(0xA3F0F2F5),
    drawerGlassFill: const Color(0xB8F0F2F5),
    borderNeutral: const Color(0xFFE0E0E0),
    textSubtext: const Color(0xFF757575),
    textDisabled: const Color(0xFFBDBDBD),
    surfaceStudyWell: const Color(0xFFE8EAED),
    surfaceGlassInput: const Color(0x12000000),
    secondaryAccent: const Color(0xFFAD1457),
    cardShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  NexusExtras copyWith({
    Color? feedbackHard,
    Color? feedbackHit,
    Color? glassFill,
    Color? drawerGlassFill,
    Color? borderNeutral,
    Color? textSubtext,
    Color? textDisabled,
    Color? surfaceStudyWell,
    Color? surfaceGlassInput,
    Color? secondaryAccent,
    List<BoxShadow>? cardShadows,
  }) {
    return NexusExtras(
      feedbackHard: feedbackHard ?? this.feedbackHard,
      feedbackHit: feedbackHit ?? this.feedbackHit,
      glassFill: glassFill ?? this.glassFill,
      drawerGlassFill: drawerGlassFill ?? this.drawerGlassFill,
      borderNeutral: borderNeutral ?? this.borderNeutral,
      textSubtext: textSubtext ?? this.textSubtext,
      textDisabled: textDisabled ?? this.textDisabled,
      surfaceStudyWell: surfaceStudyWell ?? this.surfaceStudyWell,
      surfaceGlassInput: surfaceGlassInput ?? this.surfaceGlassInput,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      cardShadows: cardShadows ?? this.cardShadows,
    );
  }

  @override
  ThemeExtension<NexusExtras> lerp(
    ThemeExtension<NexusExtras>? other,
    double t,
  ) {
    if (other is! NexusExtras) return this;
    if (t < 0.5) return this;
    return other;
  }
}

extension NexusThemeContext on BuildContext {
  /// [NexusExtras] for the current theme (dark fallback if missing).
  NexusExtras get nexusExtras =>
      Theme.of(this).extension<NexusExtras>() ?? NexusExtras.dark;
}

extension NexusTypographyContext on BuildContext {
  /// JetBrains Mono — intervals, S/D/R, numeric data.
  TextStyle nexusMono(
    double fontSize, {
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    final c = color ?? Theme.of(this).colorScheme.onSurface;
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: c,
    );
  }

  /// Inter — lemmas, translations, prose.
  TextStyle nexusInterContent(
    double fontSize, {
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) {
    final c = color ?? Theme.of(this).colorScheme.onSurface;
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: c,
    );
  }
}

ThemeData _buildDark() {
  final scheme = ColorScheme.dark(
    primary: NexusPaletteDark.primary,
    onPrimary: NexusPaletteDark.background,
    secondary: const Color(0xFFE91E8C),
    onSecondary: Colors.white,
    tertiary: NexusPaletteDark.success,
    onTertiary: NexusPaletteDark.background,
    error: NexusPaletteDark.error,
    onError: Colors.white,
    surface: NexusPaletteDark.surface,
    onSurface: const Color(0xFFE0E0E0),
    surfaceContainerHighest: const Color(0xFF242428),
    outline: NexusPaletteDark.primary,
  );

  return _applyChrome(scheme, NexusExtras.dark, NexusPaletteDark.background);
}

ThemeData _buildLight() {
  final scheme = ColorScheme.light(
    primary: NexusPaletteLight.primary,
    onPrimary: Colors.white,
    secondary: const Color(0xFFAD1457),
    onSecondary: Colors.white,
    tertiary: NexusPaletteLight.success,
    onTertiary: Colors.white,
    error: NexusPaletteLight.error,
    onError: Colors.white,
    surface: NexusPaletteLight.surface,
    onSurface: const Color(0xFF1A1A1A),
    surfaceContainerHighest: const Color(0xFFE8EAED),
    outline: NexusPaletteLight.primary,
  );

  return _applyChrome(scheme, NexusExtras.light, NexusPaletteLight.background);
}

ThemeData _applyChrome(
  ColorScheme scheme,
  NexusExtras extras,
  Color scaffoldBackground,
) {
  final interBase = ThemeData(brightness: scheme.brightness).textTheme;
  final inter = GoogleFonts.interTextTheme(interBase).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final mono = GoogleFonts.jetBrainsMonoTextTheme(interBase);
  final textTheme = inter.copyWith(
    labelSmall: mono.labelSmall?.copyWith(color: scheme.onSurface),
    labelMedium: mono.labelMedium?.copyWith(color: scheme.onSurface),
    bodySmall: mono.bodySmall?.copyWith(color: scheme.onSurface),
    titleMedium: mono.titleMedium?.copyWith(color: scheme.onSurface),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: scaffoldBackground,
    colorScheme: scheme,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[extras],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: inter.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: extras.surfaceGlassInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.5),
      ),
      labelStyle: TextStyle(color: extras.textSubtext),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.primary,
    ),
    // Focus rings for keyboard / switch users (see nexus_a11y.dart for contrast notes).
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: scheme.primary, width: 2);
          }
          return BorderSide.none;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: scheme.primary, width: 2);
          }
          return BorderSide.none;
        }),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: scheme.primary, width: 2);
          }
          return BorderSide.none;
        }),
      ),
    ),
  );
}

/// Shared glass shell for major containers.
class NexusGlass extends StatelessWidget {
  /// Creates a frosted panel using theme glass tint + primary glow.
  const NexusGlass({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = context.nexusExtras.glassFill;
    final overlayA = SpectralHudTokens.overlayOpacity(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: SpectralHudTokens.blurSigma,
          sigmaY: SpectralHudTokens.blurSigma,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              scheme.primary.withValues(alpha: overlayA),
              fill,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.055),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// @nodoc — use [AppTheme.dark] in tests / legacy call sites.
@Deprecated('Use AppTheme.dark')
ThemeData buildNexusTheme() => AppTheme.dark;

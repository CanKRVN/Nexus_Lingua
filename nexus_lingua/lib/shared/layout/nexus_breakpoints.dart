/// Named width tiers (plan: compact / medium / expanded / large).
///
/// Aligned with `.cursorrules` `study_layout_breakpoint_width_lp` for the
/// typist vs compact study split at **840 lp** ([wideLayoutMinWidthLp]).
enum NexusLayoutClass {
  /// &lt; 600 lp — single column, tight gutters.
  compact,

  /// 600–839 lp — transitional; still single column for home shell.
  medium,

  /// 840–1199 lp — wide study typist mode, multi-column shell.
  expanded,

  /// ≥ 1200 lp — roomy desktop.
  large,
}

/// Layout breakpoints — use this API instead of raw width literals in features.
abstract final class NexusBreakpoints {
  /// Upper bound of [NexusLayoutClass.compact] (inclusive of compact below this).
  static const double compactMaxWidthLp = 599;

  /// Upper bound of [NexusLayoutClass.medium].
  static const double mediumMaxWidthLp = 839;

  /// Upper bound of [NexusLayoutClass.expanded].
  static const double expandedMaxWidthLp = 1199;

  /// At or above: multi-panel “wide” shell + typist study (PRD §7.5, `.cursorrules`).
  static const double wideLayoutMinWidthLp = 840;

  /// Short viewport: prefer compact FSRS row even when width ≥ [wideLayoutMinWidthLp].
  static const double studyCompactMaxHeightLp = 520;

  /// Max content width on [NexusLayoutClass.large] viewports (readable line length).
  static const double maxContentWidthLp = 1280;

  /// Classify viewport width (logical pixels).
  static NexusLayoutClass layoutClassForWidth(double widthLp) {
    if (widthLp <= compactMaxWidthLp) return NexusLayoutClass.compact;
    if (widthLp <= mediumMaxWidthLp) return NexusLayoutClass.medium;
    if (widthLp <= expandedMaxWidthLp) return NexusLayoutClass.expanded;
    return NexusLayoutClass.large;
  }

  /// True when [NexusResponsiveShell] should show [leading] / [trailing] columns.
  static bool isWideLayout(double widthLp) =>
      widthLp >= wideLayoutMinWidthLp;

  /// Horizontal body padding for [NexusPageScaffold]-style gutters.
  static double bodyHorizontalPaddingLp(double widthLp) {
    final c = layoutClassForWidth(widthLp);
    return switch (c) {
      NexusLayoutClass.compact => 16,
      NexusLayoutClass.medium => 20,
      NexusLayoutClass.expanded => 24,
      NexusLayoutClass.large => 28,
    };
  }
}

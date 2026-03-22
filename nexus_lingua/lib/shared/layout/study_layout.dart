import 'package:flutter/widgets.dart';

import 'nexus_breakpoints.dart';

/// Chooses typist (SimilarityEvaluator) vs compact (4-button) study interaction.
///
/// Uses viewport width only so the same library compiles for web and native
/// (`.cursorrules` §3.3 — no `dart:io` / [Platform]).
abstract final class StudyLayout {
  /// When true: wide viewport — show text input + automated scoring (PRD §5.1).
  ///
  /// Gated by [NexusBreakpoints.wideLayoutMinWidthLp] (840 logical pixels).
  static bool useTypistMode(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= NexusBreakpoints.wideLayoutMinWidthLp;
  }
}

import 'package:flutter/widgets.dart';

import 'nexus_breakpoints.dart';

/// Chooses typist (SimilarityEvaluator) vs compact (4-button) study interaction.
///
/// Uses [MediaQuery] size only so the same library compiles for web and native
/// (`.cursorrules` §3.3 — no `dart:io` / [Platform]).
abstract final class StudyLayout {
  /// When true: wide viewport — show text input + automated scoring (PRD §5.1).
  ///
  /// Gated by [NexusBreakpoints.wideLayoutMinWidthLp] (840 logical pixels) and
  /// a **height** floor: very short windows keep the compact rating row so the
  /// field and actions stay usable ([NexusBreakpoints.studyCompactMaxHeightLp]).
  static bool useTypistMode(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (!NexusBreakpoints.isWideLayout(size.width)) return false;
    if (size.height < NexusBreakpoints.studyCompactMaxHeightLp) return false;
    return true;
  }
}

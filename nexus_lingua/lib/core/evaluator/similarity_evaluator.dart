import '../models/word_card.dart';
import 'evaluation_result.dart';

/// Normalized Levenshtein → FSRS rating mapping (typist / wide study mode).
///
/// Pure logic: no I/O, no Flutter (`.cursorrules` §4.1).
class SimilarityEvaluator {
  /// Creates a similarity evaluator.
  const SimilarityEvaluator();

  /// Standard Levenshtein distance (DP, O(m·n)).
  int computeLevenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    var previous = List<int>.generate(n + 1, (j) => j);
    var current = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      current[0] = i;
      final ac = a.codeUnitAt(i - 1);
      for (var j = 1; j <= n; j++) {
        final cost = ac == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = _min3(
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[n];
  }

  int _min3(int a, int b, int c) {
    var m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
  }

  /// R = 1 − d / max(len(U), len(T)); clamped to [0, 1].
  double computeRatio(String userInput, String target, bool caseSensitive) {
    final u = caseSensitive ? userInput : userInput.toLowerCase();
    final t = caseSensitive ? target : target.toLowerCase();
    if (u.isEmpty && t.isEmpty) return 1.0;
    final maxLen = u.length > t.length ? u.length : t.length;
    if (maxLen == 0) return 1.0;
    final d = computeLevenshtein(u, t);
    final r = 1.0 - d / maxLen;
    return r.clamp(0.0, 1.0);
  }

  /// Maps similarity ratio to FSRS rating 1..4 (strict thresholds).
  int mapToFSRS(double ratio) {
    if (ratio == 1.0) return 4;
    if (ratio >= 0.85) return 3;
    if (ratio >= 0.65) return 2;
    return 1;
  }

  /// Full pipeline using `card.metadata['case_sensitive']`.
  EvaluationResult evaluate(String userInput, WordCard card) {
    final caseSensitive = card.metadata['case_sensitive'] == true;
    final ratio = computeRatio(userInput, card.lemma, caseSensitive);
    final fsrsRating = mapToFSRS(ratio);
    final label = _labelFor(fsrsRating);
    return EvaluationResult(
      ratio: ratio,
      fsrsRating: fsrsRating,
      label: label,
    );
  }

  static String _labelFor(int fsrsRating) {
    switch (fsrsRating) {
      case 4:
        return 'Crit!';
      case 3:
        return 'Hit';
      case 2:
        return 'Hard';
      default:
        return 'Miss';
    }
  }
}

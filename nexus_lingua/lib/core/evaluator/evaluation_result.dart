/// Outcome of [SimilarityEvaluator.evaluate].
class EvaluationResult {
  /// Creates an evaluation result.
  const EvaluationResult({
    required this.ratio,
    required this.fsrsRating,
    required this.label,
  });

  /// Normalized Levenshtein similarity in [0, 1].
  final double ratio;

  /// Mapped FSRS button 1..4.
  final int fsrsRating;

  /// UI label: Crit!, Hit, Hard, Miss.
  final String label;
}

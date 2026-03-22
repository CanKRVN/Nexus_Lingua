import 'dart:math' as math;

import '../models/word_card.dart';

/// FSRS-4.5 scheduler: pure Dart, no external SRS packages (auditable).
///
/// Uses the 17 default weights from the Nexus Lingua PRD. Equations follow
/// the open-spaced-repetition FSRS-4.5 formulation (recall / forget /
/// difficulty updates). Stored **retrievability** on the card uses the PRD
/// convention [R(t) = 0.9^(t/S)] at the instant after a review (t = 0 ⇒ R = 1).
class FSRSEngine {
  /// Creates an engine with the published FSRS-4.5 default weights.
  const FSRSEngine({List<double>? weights})
      : w = weights ?? _defaultWeights17;

  /// 17 FSRS-4.5 parameters (w₀…w₁₆).
  final List<double> w;

  /// PRD / `.cursorrules` default FSRS-4.5 weights.
  static const List<double> _defaultWeights17 = [
    0.4,
    0.6,
    2.4,
    5.8,
    4.93,
    0.94,
    0.86,
    0.01,
    1.49,
    0.14,
    0.94,
    2.18,
    0.05,
    0.34,
    1.26,
    0.29,
    2.61,
  ];

  /// Returns a new [WordCard] after applying [rating] (1–4) at [now].
  ///
  /// Does not mutate [card]. [dueDate] is set to `now + Duration(days: S.round())`
  /// per project rules.
  WordCard schedule(WordCard card, int rating, DateTime now) {
    assert(rating >= 1 && rating <= 4, 'FSRS rating must be 1..4');

    if (card.reviewCount == 0) {
      return _firstReview(card, rating, now);
    }
    return _subsequentReview(card, rating, now);
  }

  /// First graded review: initial stability w[rating−1], initial difficulty.
  WordCard _firstReview(WordCard card, int rating, DateTime now) {
    final newS = math.max(w[rating - 1], 0.1);
    final newD = _initDifficulty(rating);
    final due = now.add(Duration(days: newS.round()));
    return card.copyWith(
      stability: newS,
      difficulty: newD,
      retrievability: 1.0,
      dueDate: due,
      reviewCount: card.reviewCount + 1,
      lastReviewedAt: now,
    );
  }

  /// Later reviews: elapsed days [t], then forget (Again) or recall stability.
  WordCard _subsequentReview(WordCard card, int rating, DateTime now) {
    final last = card.lastReviewedAt ?? now;
    final elapsedMs = now.difference(last).inMilliseconds;
    final tDays = (elapsedMs / Duration.millisecondsPerDay).clamp(0.0, 1e9);

    final s = card.stability;
    final d = card.difficulty;
    // PRD retrievability for scheduling step: R = 0.9^(t/S)
    final r = math.pow(0.9, tDays / s).toDouble().clamp(0.0, 1.0);

    final newD = _nextDifficulty(d, rating);
    final newS = rating == 1
        ? _nextForgetStability(d, s, r)
        : _nextRecallStability(d, s, r, rating);

    final clampedS = newS.clamp(0.1, 36500.0);
    final due = now.add(Duration(days: clampedS.round()));

    return card.copyWith(
      stability: clampedS,
      difficulty: newD,
      retrievability: 1.0,
      dueDate: due,
      reviewCount: card.reviewCount + 1,
      lastReviewedAt: now,
    );
  }

  /// Initial difficulty after first rating — FSRS-4.5 init_d.
  double _initDifficulty(int rating) {
    final raw = w[4] - math.exp(w[5] * (rating - 1)) + 1;
    return _constrainDifficulty(raw);
  }

  /// Mean reversion target: difficulty if first grade were Easy (4).
  double _initDifficultyEasy() {
    final raw = w[4] - math.exp(w[5] * 3) + 1;
    return _constrainDifficulty(raw);
  }

  /// Difficulty update — delta from rating, linear damping, mean reversion.
  double _nextDifficulty(double d, int rating) {
    final deltaD = -w[6] * (rating - 3);
    final damped = d + _linearDamping(deltaD, d);
    final reverted = w[7] * _initDifficultyEasy() + (1 - w[7]) * damped;
    return _constrainDifficulty(reverted);
  }

  double _linearDamping(double deltaD, double d) => deltaD * (10 - d) / 9;

  double _constrainDifficulty(double d) => d.clamp(1.0, 10.0);

  /// Successful review stability (Hard / Good / Easy).
  double _nextRecallStability(double d, double s, double r, int rating) {
    final hardPenalty = rating == 2 ? w[15] : 1.0;
    final easyBonus = rating == 4 ? w[16] : 1.0;
    final inner = math.exp(w[8]) *
        (11 - d) *
        math.pow(s, -w[9]) *
        (math.exp((1 - r) * w[10]) - 1) *
        hardPenalty *
        easyBonus;
    return s * (1 + inner);
  }

  /// Lapse (Again): stability after forgetting.
  double _nextForgetStability(double d, double s, double r) {
    return w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1, w[13]) - 1) *
        math.exp((1 - r) * w[14]);
  }
}

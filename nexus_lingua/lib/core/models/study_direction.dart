/// Typist prompt direction: which side is shown vs typed.
enum StudyDirection {
  /// Show target surface (article + lemma); type known gloss.
  targetToKnown,

  /// Show known gloss; type target surface (article + lemma).
  knownToTarget,
}

extension StudyDirectionLabels on StudyDirection {
  /// Short UI label, e.g. settings row.
  String get shortLabel => switch (this) {
        StudyDirection.targetToKnown => 'Target → Known',
        StudyDirection.knownToTarget => 'Known → Target',
      };

  /// Tooltip / subtitle.
  String get description => switch (this) {
        StudyDirection.targetToKnown =>
          'See the word you are learning; type its meaning in your language.',
        StudyDirection.knownToTarget =>
          'See the meaning in your language; type the word you are learning.',
      };
}

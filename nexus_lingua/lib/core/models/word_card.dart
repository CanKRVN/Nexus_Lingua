import 'dart:convert';

/// One vocabulary card: lemma, translation, FSRS state, and φ metadata (JSON).
class WordCard {
  /// Creates a word card.
  const WordCard({
    this.id,
    required this.profileId,
    required this.lemma,
    required this.translation,
    this.stability = 1.0,
    this.difficulty = 5.0,
    this.retrievability = 1.0,
    required this.dueDate,
    this.reviewCount = 0,
    this.metadata = const {},
    required this.createdAt,
    this.lastReviewedAt,
  });

  /// Row id from SQLite, null before insert.
  final int? id;

  /// Foreign key to [LanguageProfile].
  final int profileId;

  /// Primary form being learned (L).
  final String lemma;

  /// Gloss / translation (T).
  final String translation;

  /// FSRS stability S (days).
  final double stability;

  /// FSRS difficulty D in [1, 10].
  final double difficulty;

  /// FSRS retrievability R in [0, 1].
  final double retrievability;

  /// Next scheduled review instant.
  final DateTime dueDate;

  final int reviewCount;

  /// Language-specific φ map; never parsed in SQL.
  final Map<String, dynamic> metadata;

  final DateTime createdAt;

  /// Last review instant; null if never reviewed (FSRS first step).
  final DateTime? lastReviewedAt;

  /// Copy with selective overrides (immutable update).
  WordCard copyWith({
    int? id,
    int? profileId,
    String? lemma,
    String? translation,
    double? stability,
    double? difficulty,
    double? retrievability,
    DateTime? dueDate,
    int? reviewCount,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
  }) {
    return WordCard(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      lemma: lemma ?? this.lemma,
      translation: translation ?? this.translation,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      dueDate: dueDate ?? this.dueDate,
      reviewCount: reviewCount ?? this.reviewCount,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  /// Serializes for SQLite (`metadata` JSON-encoded).
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'profile_id': profileId,
      'lemma': lemma,
      'translation': translation,
      'stability': stability,
      'difficulty': difficulty,
      'retrievability': retrievability,
      'due_date': dueDate.millisecondsSinceEpoch ~/ 1000,
      'review_count': reviewCount,
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'last_reviewed_at': lastReviewedAt != null
          ? lastReviewedAt!.millisecondsSinceEpoch ~/ 1000
          : 0,
    };
  }

  /// Deserializes from a SQLite row map.
  factory WordCard.fromMap(Map<String, Object?> map) {
    final metaRaw = map['metadata'];
    final Map<String, dynamic> meta;
    if (metaRaw is String && metaRaw.isNotEmpty) {
      final decoded = jsonDecode(metaRaw);
      meta = Map<String, dynamic>.from(decoded as Map<dynamic, dynamic>);
    } else {
      meta = {};
    }
    final lastRev = map['last_reviewed_at'] as int? ?? 0;
    return WordCard(
      id: map['id'] as int?,
      profileId: map['profile_id'] as int,
      lemma: map['lemma'] as String,
      translation: map['translation'] as String,
      stability: (map['stability'] as num?)?.toDouble() ?? 1.0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 5.0,
      retrievability: (map['retrievability'] as num?)?.toDouble() ?? 1.0,
      dueDate: DateTime.fromMillisecondsSinceEpoch(
        ((map['due_date'] as int?) ?? 0) * 1000,
        isUtc: true,
      ).toLocal(),
      reviewCount: map['review_count'] as int? ?? 0,
      metadata: meta,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['created_at'] as int?) ?? 0) * 1000,
        isUtc: true,
      ).toLocal(),
      lastReviewedAt: lastRev > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastRev * 1000, isUtc: true)
              .toLocal()
          : null,
    );
  }
}

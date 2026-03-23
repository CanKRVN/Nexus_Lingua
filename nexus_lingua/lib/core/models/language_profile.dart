import 'dart:convert';

/// A language configuration: target language (learning) + known language (L1).
///
/// [language] + [features] describe the **target** side; [knownLanguage] +
/// [featuresKnown] the **known** side (e.g. English gloss metadata).
class LanguageProfile {
  /// Creates a language profile.
  const LanguageProfile({
    this.id,
    required this.language,
    required this.features,
    this.knownLanguage = '',
    this.featuresKnown = const [],
    required this.createdAt,
  });

  /// Row id from SQLite, null before insert.
  final int? id;

  /// Target language name (what you are learning), e.g. `German`.
  final String language;

  /// Metadata feature keys for the **target** language (stored as JSON in SQLite).
  final List<String> features;

  /// Known / native language label, e.g. `English` (optional).
  final String knownLanguage;

  /// Metadata feature keys for the **known** language side.
  final List<String> featuresKnown;

  final DateTime createdAt;

  /// List tile / picker, e.g. `German ← English`.
  String get displayDeckTitle {
    final k = knownLanguage.trim();
    if (k.isEmpty) return language;
    return '$language ← $k';
  }

  /// Serializes for SQLite (`features` as JSON text).
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'language': language,
      'features': jsonEncode(features),
      'known_language': knownLanguage,
      'features_known': jsonEncode(featuresKnown),
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Deserializes from a SQLite row map.
  factory LanguageProfile.fromMap(Map<String, Object?> map) {
    final featuresRaw = map['features'];
    final List<String> parsed;
    if (featuresRaw is String) {
      final decoded = jsonDecode(featuresRaw);
      parsed = (decoded as List<dynamic>).cast<String>();
    } else {
      parsed = [];
    }
    final fkRaw = map['features_known'];
    final List<String> parsedKnown;
    if (fkRaw is String) {
      final decoded = jsonDecode(fkRaw);
      parsedKnown = (decoded as List<dynamic>).cast<String>();
    } else {
      parsedKnown = [];
    }
    return LanguageProfile(
      id: map['id'] as int?,
      language: map['language'] as String,
      features: parsed,
      knownLanguage: (map['known_language'] as String?) ?? '',
      featuresKnown: parsedKnown,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['created_at'] as int?) ?? 0) * 1000,
        isUtc: true,
      ).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageProfile && id != null && id == other.id;
  }

  @override
  int get hashCode => Object.hash(LanguageProfile, id);
}

import 'dart:convert';

/// A language configuration: which linguistic features (F) are active for cards.
class LanguageProfile {
  /// Creates a language profile.
  const LanguageProfile({
    this.id,
    required this.language,
    required this.features,
    required this.createdAt,
  });

  /// Row id from SQLite, null before insert.
  final int? id;

  /// Display name, e.g. `German`.
  final String language;

  /// Active feature keys (stored as JSON array in SQLite).
  final List<String> features;

  final DateTime createdAt;

  /// Serializes for SQLite (`features` as JSON text).
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'language': language,
      'features': jsonEncode(features),
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
    return LanguageProfile(
      id: map['id'] as int?,
      language: map['language'] as String,
      features: parsed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((map['created_at'] as int?) ?? 0) * 1000,
        isUtc: true,
      ).toLocal(),
    );
  }
}

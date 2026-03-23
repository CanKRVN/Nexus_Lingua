/// Known linguistic feature keys for [LanguageProfile.features] (PRD §4.2 / §8.1).
abstract final class LanguageFeatureCatalog {
  /// All toggles shown in the profile editor (order = UI order).
  static const List<String> allKeys = [
    'article',
    'gender',
    'plural',
    'conjugation',
    'case',
    'tense',
    'case_sensitive',
  ];

  /// Human-readable labels for checklist UI.
  static String labelFor(String key) {
    switch (key) {
      case 'article':
        return 'Article (der/die/das …)';
      case 'gender':
        return 'Gender';
      case 'plural':
        return 'Plural';
      case 'conjugation':
        return 'Conjugation';
      case 'case':
        return 'Case';
      case 'tense':
        return 'Tense';
      case 'case_sensitive':
        return 'Case-sensitive lemma match';
      default:
        return key;
    }
  }
}

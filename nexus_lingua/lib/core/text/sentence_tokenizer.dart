/// Regex tokenization for Sentence Decoder (PRD §8.4 MVP).
///
/// Splits on runs that are *not* Unicode letters, numbers, apostrophe, or
/// hyphen (whitespace / punctuation are delimiters).
abstract final class SentenceTokenizer {
  /// Delimiter: anything that is not letter, digit, `'`, or `-`.
  static final RegExp _delimiter = RegExp(
    r"[^\p{L}\p{N}'-]+",
    unicode: true,
  );

  /// Ordered tokens from [source] (empty → empty list).
  static List<String> tokenize(String source) {
    if (source.trim().isEmpty) {
      return const [];
    }
    return source
        .split(_delimiter)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

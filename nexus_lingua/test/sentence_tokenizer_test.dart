import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/core/text/sentence_tokenizer.dart';

void main() {
  group('SentenceTokenizer', () {
    test('empty and whitespace', () {
      expect(SentenceTokenizer.tokenize(''), isEmpty);
      expect(SentenceTokenizer.tokenize('   '), isEmpty);
    });

    test('splits on punctuation and spaces', () {
      expect(SentenceTokenizer.tokenize('a, b.'), ['a', 'b']);
      expect(SentenceTokenizer.tokenize('one two three'), [
        'one',
        'two',
        'three',
      ]);
    });

    test('apostrophe inside token', () {
      expect(SentenceTokenizer.tokenize("don't panic"), ["don't", 'panic']);
    });

    test('Unicode letters', () {
      expect(SentenceTokenizer.tokenize('Café résumé'), ['Café', 'résumé']);
    });

    test('preserves order', () {
      expect(SentenceTokenizer.tokenize('z a m'), ['z', 'a', 'm']);
    });
  });
}

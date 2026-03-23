import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/core/evaluator/similarity_evaluator.dart';
import 'package:nexus_lingua/core/models/study_direction.dart';
import 'package:nexus_lingua/core/models/word_card.dart';

void main() {
  const ev = SimilarityEvaluator();
  final base = DateTime.utc(2025, 1, 1);

  WordCard card({
    required String lemma,
    bool caseSensitive = false,
  }) {
    return WordCard(
      profileId: 1,
      lemma: lemma,
      translation: 'x',
      dueDate: base,
      createdAt: base,
      metadata: {'case_sensitive': caseSensitive},
    );
  }

  group('SimilarityEvaluator', () {
    test('R == 1.0 exact match case-insensitive', () {
      final r = ev.computeRatio('Hello', 'hello', false);
      expect(r, 1.0);
      expect(ev.mapToFSRS(r), 4);
    });

    test('R == 1.0 exact match case-sensitive', () {
      final r = ev.computeRatio('Ab', 'Ab', true);
      expect(r, 1.0);
    });

    test('case-sensitive mismatch passes case-insensitive', () {
      final rSensitive = ev.computeRatio('ab', 'Ab', true);
      expect(rSensitive, lessThan(1.0));
      final rIns = ev.computeRatio('ab', 'Ab', false);
      expect(rIns, 1.0);
    });

    test('one char typo short word → Hard or Miss', () {
      final r = ev.computeRatio('cat', 'bat', false);
      expect(r, lessThan(0.85));
      final g = ev.mapToFSRS(r);
      expect(g, lessThanOrEqualTo(2));
    });

    test('one char typo long word → Hit', () {
      final r = ev.computeRatio('abcdefghij', 'abcdxfghij', false);
      expect(r, greaterThanOrEqualTo(0.85));
      expect(r, lessThan(1.0));
      expect(ev.mapToFSRS(r), 3);
    });

    test('empty user input → Miss', () {
      final r = ev.computeRatio('', 'word', false);
      expect(ev.mapToFSRS(r), 1);
    });

    test('wrong word → Miss', () {
      final r = ev.computeRatio('xyz', 'abc', false);
      expect(ev.mapToFSRS(r), 1);
    });

    test('boundary R = 0.85 → Good (3)', () {
      expect(ev.mapToFSRS(0.85), 3);
    });

    test('boundary R = 0.65 → Hard (2)', () {
      expect(ev.mapToFSRS(0.65), 2);
    });

    test('Unicode lemma', () {
      final r = ev.computeRatio('über', 'über', false);
      expect(r, 1.0);
      expect(ev.evaluate('über', card(lemma: 'über')).label, 'Crit!');
    });

    test('evaluate pipeline reads case_sensitive', () {
      final res = ev.evaluate('hello', card(lemma: 'Hello'));
      expect(res.fsrsRating, 4);
      expect(res.label, 'Crit!');
    });

    test('evaluateTranslationRecall scores against translation', () {
      final w = WordCard(
        profileId: 1,
        lemma: 'das Haus',
        translation: 'the house',
        dueDate: base,
        createdAt: base,
        metadata: const {'case_sensitive': false},
      );
      final res = ev.evaluateTranslationRecall('The House', w);
      expect(res.fsrsRating, 4);
      expect(res.ratio, 1.0);
    });

    test('evaluate compares to targetSurface (article + lemma)', () {
      final w = WordCard(
        profileId: 1,
        lemma: 'Buch',
        translation: 'book',
        dueDate: base,
        createdAt: base,
        metadata: const {
          'article': 'das',
          'case_sensitive': false,
        },
      );
      expect(w.targetSurface, 'das Buch');
      expect(ev.evaluate('das buch', w).fsrsRating, 4);
    });

    test('evaluateTypistRecall knownToTarget expects targetSurface', () {
      final w = WordCard(
        profileId: 1,
        lemma: 'Buch',
        translation: 'the book',
        dueDate: base,
        createdAt: base,
        metadata: const {
          'article': 'das',
          'case_sensitive': false,
        },
      );
      final res = ev.evaluateTypistRecall(
        'das buch',
        w,
        StudyDirection.knownToTarget,
      );
      expect(res.fsrsRating, 4);
    });

    test('evaluateTypistRecall targetToKnown expects translation', () {
      final w = WordCard(
        profileId: 1,
        lemma: 'Buch',
        translation: 'the book',
        dueDate: base,
        createdAt: base,
        metadata: const {'article': 'das', 'case_sensitive': false},
      );
      final res = ev.evaluateTypistRecall(
        'The Book',
        w,
        StudyDirection.targetToKnown,
      );
      expect(res.fsrsRating, 4);
    });
  });
}

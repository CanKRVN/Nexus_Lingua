import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/core/models/word_card.dart';
import 'package:nexus_lingua/core/srs/fsrs_engine.dart';

void main() {
  final now = DateTime.utc(2025, 6, 15, 12);

  WordCard fresh({int profileId = 1}) {
    return WordCard(
      profileId: profileId,
      lemma: 'a',
      translation: 'b',
      dueDate: now,
      createdAt: now,
      reviewCount: 0,
    );
  }

  group('FSRSEngine', () {
    test('first review Good (3) uses w[2] stability', () {
      const engine = FSRSEngine();
      final out = engine.schedule(fresh(), 3, now);
      expect(out.stability, 2.4);
      expect(out.reviewCount, 1);
      expect(out.lastReviewedAt, now);
      expect(
        out.dueDate.difference(now).inDays,
        2,
      );
    });

    test('first review Again (1) uses w[0]', () {
      const engine = FSRSEngine();
      final out = engine.schedule(fresh(), 1, now);
      expect(out.stability, 0.4);
      expect(out.reviewCount, 1);
    });

    test('first review Easy (4) uses w[3]', () {
      const engine = FSRSEngine();
      final out = engine.schedule(fresh(), 4, now);
      expect(out.stability, 5.8);
    });

    test('difficulty in range after first review', () {
      const engine = FSRSEngine();
      final out = engine.schedule(fresh(), 3, now);
      expect(out.difficulty, inInclusiveRange(1.0, 10.0));
    });

    test('subsequent review does not throw and increments count', () {
      const engine = FSRSEngine();
      final once = engine.schedule(fresh(), 3, now);
      final withId = once.copyWith(id: 1);
      final dayLater = now.add(const Duration(days: 1));
      final twice = engine.schedule(withId, 3, dayLater);
      expect(twice.reviewCount, 2);
      expect(twice.stability, greaterThan(0));
      expect(twice.difficulty, inInclusiveRange(1.0, 10.0));
    });
  });
}

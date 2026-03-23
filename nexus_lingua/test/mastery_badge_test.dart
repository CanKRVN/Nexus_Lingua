import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/shared/widgets/mastery_badge.dart';

void main() {
  test('mastery tiers by stability boundaries', () {
    expect(masteryTierForStability(0.5), MasteryTier.novice);
    expect(masteryTierForStability(1.0), MasteryTier.apprentice);
    expect(masteryTierForStability(7.0), MasteryTier.journeyman);
    expect(masteryTierForStability(30.0), MasteryTier.elite);
    expect(masteryTierForStability(120.0), MasteryTier.legend);
  });
}

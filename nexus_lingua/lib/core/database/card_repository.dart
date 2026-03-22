import '../models/language_profile.dart';
import '../models/word_card.dart';
import 'database_helper.dart';

/// UI-facing data API; wraps [DatabaseHelper] only.
class CardRepository {
  /// Creates a repository using [helper] (inject for tests).
  CardRepository({DatabaseHelper? helper}) : _db = helper ?? DatabaseHelper();

  final DatabaseHelper _db;

  /// Cards due for review at [now] for [profileId] (`due_date <= now`).
  Future<List<WordCard>> loadDueCardsForProfile(
    int profileId,
    DateTime now,
  ) {
    return _db.getDueCards(profileId, now);
  }

  /// Inserts a new [WordCard]; returns the SQLite row id.
  Future<int> insertCard(WordCard card) => _db.insertCard(card);

  /// Distinct lemmas in [profileId] for Sentence Decoder known-token underline.
  Future<Set<String>> loadLemmaSetForProfile(int profileId) {
    return _db.getLemmaSetForProfile(profileId);
  }

  /// Writes updated card state and appends `review_log` (PRD study engine).
  ///
  /// [updatedCard] must include [WordCard.id]. [stabilityBefore] is S prior
  /// to scheduling. [similarityR] is for typist mode (Phase 4); omit in
  /// compact rating flow.
  Future<void> commitReview({
    required WordCard updatedCard,
    required int rating,
    required double stabilityBefore,
    double? similarityR,
  }) async {
    if (updatedCard.id == null) {
      throw ArgumentError.value(
        updatedCard.id,
        'updatedCard.id',
        'Required to persist review',
      );
    }
    await _db.updateCardAfterReview(updatedCard);
    await _db.insertReviewLog(
      cardId: updatedCard.id!,
      rating: rating,
      similarityR: similarityR,
      sBefore: stabilityBefore,
      sAfter: updatedCard.stability,
    );
  }

  /// Opens DB, runs [DatabaseHelper.seedDatabase], returns seed status message.
  Future<String> bootstrapPersistence() async {
    await _db.getDatabase();
    final before = await _db.countProfiles();
    await _db.seedDatabase();
    final after = await _db.countProfiles();
    if (before == 0 && after > 0) {
      return 'Database initialized — seeded German deck ($after profile).';
    }
    if (after > 0) {
      return 'Database initialized — existing data ($after profile(s)).';
    }
    return 'Database initialized.';
  }

  /// All cards for the first profile (prototype helper).
  Future<List<WordCard>> loadFirstProfileCards() async {
    final db = await _db.getDatabase();
    final rows = await db.query('language_profiles', limit: 1, orderBy: 'id ASC');
    if (rows.isEmpty) return [];
    final id = rows.first['id'] as int;
    return _db.getCardsForProfile(id);
  }

  /// First profile row, if any.
  Future<LanguageProfile?> firstProfile() async {
    final db = await _db.getDatabase();
    final rows = await db.query('language_profiles', limit: 1, orderBy: 'id ASC');
    if (rows.isEmpty) return null;
    return LanguageProfile.fromMap(rows.first);
  }
}

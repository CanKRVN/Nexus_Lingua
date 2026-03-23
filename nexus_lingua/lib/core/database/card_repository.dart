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

  /// **Debug / testing only:** mark every card in the profile due now.
  Future<int> debugMarkAllCardsDueNowForProfile(int profileId) =>
      _db.debugMarkAllCardsDueNowForProfile(profileId);

  /// **Debug / testing only:** subtract [days] from every card’s due timestamp.
  Future<int> debugFastForwardDays(int profileId, int days) =>
      _db.debugFastForward(profileId, days);

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
  Future<List<WordCard>> loadFirstProfileCards() => _db.getCardsForFirstProfile();

  /// First profile row, if any.
  Future<LanguageProfile?> firstProfile() => _db.getFirstProfile();

  /// All profiles (deck list).
  Future<List<LanguageProfile>> loadAllProfiles() => _db.getAllProfiles();

  /// Cards for a single profile.
  Future<List<WordCard>> loadCardsForProfile(int profileId) =>
      _db.getCardsForProfile(profileId);

  /// Persists a new profile; returns row id.
  Future<int> insertProfile(LanguageProfile profile) =>
      _db.insertProfile(profile);

  /// Updates profile row ([LanguageProfile.id] required).
  Future<void> updateProfile(LanguageProfile profile) =>
      _db.updateProfile(profile);

  /// Deletes profile and dependent rows.
  Future<void> deleteProfile(int profileId) => _db.deleteProfile(profileId);

  /// Deletes card and its review_log rows.
  Future<void> deleteCard(int cardId) => _db.deleteCard(cardId);

  /// Full card update for CRUD ([WordCard.id] required).
  Future<void> updateCard(WordCard card) => _db.updateWordCard(card);

  /// ΣS across all cards (dashboard).
  Future<double> sumAllStability() => _db.sumAllStability();

  /// Distinct local days with reviews, newest first (`yyyy-MM-dd`).
  Future<List<String>> loadDistinctReviewDaysDescending() =>
      _db.getDistinctReviewDaysDescending();

  /// Review counts per day for heatmap.
  Future<Map<String, int>> loadReviewCountsByDayLast(int days) =>
      _db.getReviewCountsByDayLast(days);

  /// Imports backup JSON (profiles, cards, optional `app_preferences`).
  Future<({int profiles, int cards, int preferences})>
      importBackupProfilesAndCards(String json) =>
          _db.importProfilesAndCardsFromJson(json);

  /// Full JSON backup (PRD §8.5).
  Future<String> exportBackupJson() => _db.exportToJson();
}

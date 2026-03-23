import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/language_profile.dart';
import '../models/word_card.dart';
import 'sqflite_platform.dart';

/// Singleton SQLite access (`nexus_lingua.db`). Exclusive holder of [Database].
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper _instance = DatabaseHelper._internal();

  /// Global singleton.
  factory DatabaseHelper() => _instance;

  static const String _dbName = 'nexus_lingua.db';
  static const int _schemaVersion = 3;

  /// When set (VM tests only), [getDatabase] opens this path instead of app docs.
  @visibleForTesting
  static String? debugDatabaseAbsolutePath;

  Database? _db;

  /// In-flight open; prevents concurrent [openDatabase] on the same path (singleton).
  Future<Database>? _openFuture;

  /// Lazily opens the database (web factory configured first).
  ///
  /// Concurrent callers await the same [Future] so only one native open runs.
  Future<Database> getDatabase() async {
    final existing = _db;
    if (existing != null) {
      if (existing.isOpen) return existing;
      _db = null;
    }

    _openFuture ??= _openDatabaseOnce();
    try {
      final db = await _openFuture!;
      if (!db.isOpen) {
        return getDatabase();
      }
      _db = db;
      return db;
    } finally {
      _openFuture = null;
    }
  }

  Future<Database> _openDatabaseOnce() async {
    await configureSqfliteForPlatform();
    final String path;
    if (debugDatabaseAbsolutePath != null) {
      path = debugDatabaseAbsolutePath!;
    } else if (kIsWeb) {
      // Web: `path_provider` has no real documents directory — it can throw
      // `MissingPluginException`. After `databaseFactoryFfiWeb`, use sqflite's
      // databases path (backed by IndexedDB for our factory; `.cursorrules`).
      final root = await getDatabasesPath();
      path = p.join(root, _dbName);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, _dbName);
    }
    final db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await db.execute('PRAGMA foreign_keys = ON');
    // Avoid indefinite waits if a second connection ever contends (tests / races).
    await db.execute('PRAGMA busy_timeout = 8000');
    return db;
  }

  /// Closes the singleton connection (for tests or process teardown).
  @visibleForTesting
  Future<void> closeDatabaseForTesting() async {
    if (_openFuture != null) {
      try {
        final db = await _openFuture!;
        if (db.isOpen) await db.close();
      } catch (_) {
        // Open failed mid-flight; nothing to close.
      }
    }
    _openFuture = null;
    final held = _db;
    _db = null;
    if (held != null && held.isOpen) {
      try {
        await held.close();
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE language_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  language TEXT NOT NULL,
  features TEXT NOT NULL,
  known_language TEXT NOT NULL DEFAULT '',
  features_known TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL
)
''');
    await db.execute('''
CREATE TABLE word_cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER NOT NULL REFERENCES language_profiles(id),
  lemma TEXT NOT NULL,
  translation TEXT NOT NULL,
  stability REAL NOT NULL DEFAULT 1.0,
  difficulty REAL NOT NULL DEFAULT 5.0,
  retrievability REAL NOT NULL DEFAULT 1.0,
  due_date INTEGER NOT NULL DEFAULT 0,
  review_count INTEGER NOT NULL DEFAULT 0,
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,
  last_reviewed_at INTEGER NOT NULL DEFAULT 0
)
''');
    await db.execute('''
CREATE TABLE review_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER NOT NULL REFERENCES word_cards(id),
  rated_at INTEGER NOT NULL,
  rating INTEGER NOT NULL,
  similarity_r REAL,
  s_before REAL NOT NULL,
  s_after REAL NOT NULL
)
''');
    await db.execute('''
CREATE TABLE app_preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
ALTER TABLE language_profiles ADD COLUMN known_language TEXT NOT NULL DEFAULT ''
''');
      await db.execute('''
ALTER TABLE language_profiles ADD COLUMN features_known TEXT NOT NULL DEFAULT '[]'
''');
    }
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE app_preferences (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');
    }
  }

  /// Single string preference (e.g. theme mode).
  Future<String?> getAppPreference(String key) async {
    final db = await getDatabase();
    final rows = await db.query(
      'app_preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Upserts a string preference.
  Future<void> setAppPreference(String key, String value) async {
    final db = await getDatabase();
    await db.insert(
      'app_preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts a profile; returns row id.
  Future<int> insertProfile(LanguageProfile profile) async {
    final db = await getDatabase();
    return db.insert('language_profiles', profile.toMap());
  }

  /// Inserts a card; returns row id.
  Future<int> insertCard(WordCard card) async {
    final db = await getDatabase();
    return db.insert('word_cards', card.toMap()..remove('id'));
  }

  /// All cards for a language profile.
  Future<List<WordCard>> getCardsForProfile(int profileId) async {
    final db = await getDatabase();
    final rows = await db.query(
      'word_cards',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'lemma COLLATE NOCASE',
    );
    return rows.map(WordCard.fromMap).toList();
  }

  /// Lemmas in [profileId] for Sentence Decoder underline (PRD §8.4).
  ///
  /// Returned as a [Set] for membership checks; duplicates in DB collapse.
  Future<Set<String>> getLemmaSetForProfile(int profileId) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
      'SELECT lemma FROM word_cards WHERE profile_id = ?',
      [profileId],
    );
    return rows.map((r) => r['lemma']! as String).toSet();
  }

  /// Due cards for profile at [now].
  Future<List<WordCard>> getDueCards(int profileId, DateTime now) async {
    final db = await getDatabase();
    final ts = now.millisecondsSinceEpoch ~/ 1000;
    final rows = await db.query(
      'word_cards',
      where: 'profile_id = ? AND due_date <= ?',
      whereArgs: [profileId, ts],
      orderBy: 'due_date ASC',
    );
    return rows.map(WordCard.fromMap).toList();
  }

  /// **Debug / testing only:** sets every card in [profileId] to due now
  /// (`due_date = now`). Returns the number of rows updated.
  ///
  /// Remove or gate callers before shipping; study UI uses [kDebugMode].
  Future<int> debugMarkAllCardsDueNowForProfile(int profileId) async {
    final db = await getDatabase();
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.update(
      'word_cards',
      {'due_date': ts},
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
  }

  /// **Debug / testing only:** subtract [days] calendar days from every card’s
  /// `due_date` in [profileId] (simulates time passing). Clamps at epoch 0.
  ///
  /// Returns the number of rows updated.
  Future<int> debugFastForward(int profileId, int days) async {
    if (days <= 0) {
      return 0;
    }
    final db = await getDatabase();
    final deltaSec = days * 86400;
    return db.rawUpdate(
      'UPDATE word_cards SET due_date = MAX(0, due_date - ?) WHERE profile_id = ?',
      [deltaSec, profileId],
    );
  }

  /// Persists card state after a review (expects [card.id] set).
  Future<void> updateCardAfterReview(WordCard card) async {
    final db = await getDatabase();
    if (card.id == null) {
      throw StateError('updateCardAfterReview requires card.id');
    }
    await db.update(
      'word_cards',
      card.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  /// Appends a review log row.
  Future<void> insertReviewLog({
    required int cardId,
    required int rating,
    double? similarityR,
    required double sBefore,
    required double sAfter,
  }) async {
    final db = await getDatabase();
    await db.insert('review_log', {
      'card_id': cardId,
      'rated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'rating': rating,
      'similarity_r': similarityR,
      's_before': sBefore,
      's_after': sAfter,
    });
  }

  /// JSON backup of profiles, cards, review_log, and `app_preferences` (theme, etc.).
  Future<String> exportToJson() async {
    final db = await getDatabase();
    final profiles = await db.query('language_profiles');
    final cards = await db.query('word_cards');
    final logs = await db.query('review_log');
    final prefs = await db.query('app_preferences');
    return const JsonEncoder.withIndent('  ').convert({
      'language_profiles': profiles,
      'word_cards': cards,
      'review_log': logs,
      'app_preferences': prefs,
    });
  }

  /// Total profile count.
  Future<int> countProfiles() async {
    final db = await getDatabase();
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM language_profiles');
    return (r.first['c'] as int?) ?? 0;
  }

  /// Seeds German demo data when the DB has no profiles.
  Future<void> seedDatabase() async {
    final db = await getDatabase();
    final n = await countProfiles();
    if (n > 0) return;

    final now = DateTime.now();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;

    final profileId = await db.insert('language_profiles', {
      'language': 'German',
      'known_language': 'English',
      'features': jsonEncode(
        <String>['article', 'gender', 'plural', 'case_sensitive'],
      ),
      'features_known': jsonEncode(<String>['case_sensitive']),
      'created_at': nowSec,
    });

    Future<int> seedCard({
      required String lemma,
      required String translation,
      required String gender,
      required String article,
      String? plural,
    }) {
      return db.insert('word_cards', {
        'profile_id': profileId,
        'lemma': lemma,
        'translation': translation,
        'stability': 1.0,
        'difficulty': 5.0,
        'retrievability': 1.0,
        'due_date': nowSec,
        'review_count': 0,
        'metadata': jsonEncode(() {
          final m = <String, dynamic>{
            'gender': gender,
            'article': article,
            'case_sensitive': false,
          };
          if (plural != null) {
            m['plural'] = plural;
          }
          return m;
        }()),
        'created_at': nowSec,
        'last_reviewed_at': 0,
      });
    }

    await seedCard(
      lemma: 'Hund',
      translation: 'the dog',
      gender: 'masculine',
      article: 'der',
      plural: 'die Hunde',
    );
    await seedCard(
      lemma: 'Haus',
      translation: 'the house',
      gender: 'neuter',
      article: 'das',
      plural: 'die Häuser',
    );
    await seedCard(
      lemma: 'Katze',
      translation: 'the cat',
      gender: 'feminine',
      article: 'die',
      plural: 'die Katzen',
    );
    await seedCard(
      lemma: 'Buch',
      translation: 'the book',
      gender: 'neuter',
      article: 'das',
      plural: 'die Bücher',
    );
    await seedCard(
      lemma: 'Mann',
      translation: 'the man',
      gender: 'masculine',
      article: 'der',
      plural: 'die Männer',
    );
  }

  /// All language profiles, oldest first.
  Future<List<LanguageProfile>> getAllProfiles() async {
    final db = await getDatabase();
    final rows = await db.query('language_profiles', orderBy: 'id ASC');
    return rows.map(LanguageProfile.fromMap).toList();
  }

  /// First profile by ascending `id`, or null if none.
  Future<LanguageProfile?> getFirstProfile() async {
    final db = await getDatabase();
    final rows = await db.query('language_profiles', limit: 1, orderBy: 'id ASC');
    if (rows.isEmpty) return null;
    return LanguageProfile.fromMap(rows.first);
  }

  /// Cards for the first profile (by `id`), or empty if no profile.
  Future<List<WordCard>> getCardsForFirstProfile() async {
    final profile = await getFirstProfile();
    final id = profile?.id;
    if (id == null) return [];
    return getCardsForProfile(id);
  }

  /// Updates an existing profile row ([profile.id] required).
  Future<void> updateProfile(LanguageProfile profile) async {
    if (profile.id == null) {
      throw StateError('updateProfile requires profile.id');
    }
    final db = await getDatabase();
    await db.update(
      'language_profiles',
      profile.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  /// Deletes profile, its cards, and those cards' review_log rows.
  Future<void> deleteProfile(int profileId) async {
    final db = await getDatabase();
    final cardRows = await db.query(
      'word_cards',
      columns: ['id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    for (final row in cardRows) {
      final cid = row['id'] as int;
      await db.delete('review_log', where: 'card_id = ?', whereArgs: [cid]);
    }
    await db.delete('word_cards', where: 'profile_id = ?', whereArgs: [profileId]);
    await db.delete('language_profiles', where: 'id = ?', whereArgs: [profileId]);
  }

  /// Deletes a card and its `review_log` rows.
  Future<void> deleteCard(int cardId) async {
    final db = await getDatabase();
    await db.delete('review_log', where: 'card_id = ?', whereArgs: [cardId]);
    await db.delete('word_cards', where: 'id = ?', whereArgs: [cardId]);
  }

  /// Full card row update (CRUD); [card.id] required.
  Future<void> updateWordCard(WordCard card) async {
    if (card.id == null) {
      throw StateError('updateWordCard requires card.id');
    }
    final db = await getDatabase();
    await db.update(
      'word_cards',
      card.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  /// Sum of stability (ΣS) across all cards.
  Future<double> sumAllStability() async {
    final db = await getDatabase();
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(stability), 0) AS s FROM word_cards',
    );
    return ((r.first['s'] as num?) ?? 0).toDouble();
  }

  /// Distinct local calendar days with ≥1 review, `yyyy-MM-dd`, newest first.
  Future<List<String>> getDistinctReviewDaysDescending() async {
    final db = await getDatabase();
    final rows = await db.rawQuery('''
SELECT DISTINCT date(rated_at, 'unixepoch', 'localtime') AS d
FROM review_log
ORDER BY d DESC
''');
    return rows.map((e) => e['d']! as String).toList();
  }

  /// Review counts per local day for the last [days] days (for heatmap).
  Future<Map<String, int>> getReviewCountsByDayLast(int days) async {
    final db = await getDatabase();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffSec = cutoff.millisecondsSinceEpoch ~/ 1000;
    final rows = await db.rawQuery('''
SELECT date(rated_at, 'unixepoch', 'localtime') AS d, COUNT(*) AS c
FROM review_log
WHERE rated_at >= ?
GROUP BY d
ORDER BY d ASC
''', [cutoffSec]);
    final out = <String, int>{};
    for (final row in rows) {
      out[row['d']! as String] = (row['c'] as int?) ?? 0;
    }
    return out;
  }

  /// Imports profiles, cards, and optional `app_preferences` from export-shaped JSON.
  ///
  /// Ignores `review_log` (append-only history is not merged from backup).
  /// When `app_preferences` is present, rows are upserted by primary key.
  ///
  /// Returns counts for `(profilesImported, cardsImported, preferencesImported)`.
  Future<({int profiles, int cards, int preferences})>
      importProfilesAndCardsFromJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw FormatException('Backup root must be a JSON object');
    }
    final root = Map<String, dynamic>.from(decoded);
    final profilesRaw = root['language_profiles'];
    final cardsRaw = root['word_cards'];
    if (profilesRaw is! List || cardsRaw is! List) {
      throw FormatException('Expected language_profiles and word_cards arrays');
    }

    final db = await getDatabase();
    final idMap = <int, int>{};
    var pCount = 0;
    var cCount = 0;
    var prefCount = 0;

    Map<String, Object?> coerceRow(Map<dynamic, dynamic> raw) {
      return raw.map((k, v) => MapEntry(k.toString(), v as Object?));
    }

    final prefsRaw = root['app_preferences'];

    await db.transaction((txn) async {
      for (final item in profilesRaw) {
        if (item is! Map) continue;
        final row = coerceRow(item);
        final oldId = row['id'] as int?;
        row.remove('id');
        final newId = await txn.insert('language_profiles', row);
        if (oldId != null) {
          idMap[oldId] = newId;
        }
        pCount++;
      }
      for (final item in cardsRaw) {
        if (item is! Map) continue;
        final row = coerceRow(item);
        row.remove('id');
        final oldPid = row['profile_id'] as int?;
        if (oldPid != null && idMap.containsKey(oldPid)) {
          row['profile_id'] = idMap[oldPid]!;
        }
        await txn.insert('word_cards', row);
        cCount++;
      }
      if (prefsRaw is List) {
        for (final item in prefsRaw) {
          if (item is! Map) continue;
          final row = coerceRow(item);
          row.remove('id');
          await txn.insert(
            'app_preferences',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          prefCount++;
        }
      }
    });

    return (profiles: pCount, cards: cCount, preferences: prefCount);
  }
}

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
  static const int _schemaVersion = 1;

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

  /// JSON backup of profiles, cards, and review_log.
  Future<String> exportToJson() async {
    final db = await getDatabase();
    final profiles = await db.query('language_profiles');
    final cards = await db.query('word_cards');
    final logs = await db.query('review_log');
    return const JsonEncoder.withIndent('  ').convert({
      'language_profiles': profiles,
      'word_cards': cards,
      'review_log': logs,
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
      'features': jsonEncode(
        <String>['gender', 'plural', 'case_sensitive'],
      ),
      'created_at': nowSec,
    });

    Future<int> seedCard({
      required String lemma,
      required String translation,
      required String gender,
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
      lemma: 'der Hund',
      translation: 'the dog',
      gender: 'masculine',
      plural: 'die Hunde',
    );
    await seedCard(
      lemma: 'das Haus',
      translation: 'the house',
      gender: 'neuter',
      plural: 'die Häuser',
    );
    await seedCard(
      lemma: 'die Katze',
      translation: 'the cat',
      gender: 'feminine',
      plural: 'die Katzen',
    );
    await seedCard(
      lemma: 'das Buch',
      translation: 'the book',
      gender: 'neuter',
      plural: 'die Bücher',
    );
    await seedCard(
      lemma: 'der Mann',
      translation: 'the man',
      gender: 'masculine',
      plural: 'die Männer',
    );
  }
}

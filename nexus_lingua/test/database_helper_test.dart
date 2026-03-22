import 'dart:io' show Directory, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/core/database/card_repository.dart';
import 'package:nexus_lingua/core/database/database_helper.dart';
import 'package:nexus_lingua/core/models/language_profile.dart';
import 'package:nexus_lingua/core/models/word_card.dart';
import 'package:nexus_lingua/core/srs/fsrs_engine.dart';
import 'package:nexus_lingua/features/study/study_session_screen.dart';
import 'package:nexus_lingua/shared/theme/app_theme.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// First due-queue load is seeded so the study screen settles without relying on
/// pump(Duration) (never idles with spinners/confetti) or long real-time waits.
/// Subsequent loads use the real DB (e.g. after a review).
final class _SeededFirstLoadRepository extends CardRepository {
  _SeededFirstLoadRepository({
    required DatabaseHelper helper,
    required List<WordCard> initialDue,
  })  : _helper = helper,
        _initialDue = List<WordCard>.from(initialDue),
        super(helper: helper);

  final DatabaseHelper _helper;
  final List<WordCard> _initialDue;
  int _loadCalls = 0;

  @override
  Future<List<WordCard>> loadDueCardsForProfile(int profileId, DateTime now) {
    if (_loadCalls++ == 0) {
      return Future<List<WordCard>>.value(List<WordCard>.from(_initialDue));
    }
    return _helper.getDueCards(profileId, now);
  }
}

/// `flutter_tester` on Windows can stall on `pump()` with full [StudySessionScreen] + FFI DB.
/// Linux CI (`.github/workflows/flutter_ci.yml`) runs these tests unskipped.
/// To attempt them locally on Windows: `FORCE_STUDY_WIDGET_TESTS=true flutter test ...` (may hang).
bool get _skipStudySessionScreenWidgets {
  if (!Platform.isWindows) return false;
  return Platform.environment['FORCE_STUDY_WIDGET_TESTS'] != 'true';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One temp dir per test; deleted in [tearDown] after DB close.
  Directory? testTempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    StudySessionScreen.debugOmitConfettiOverlay = true;
  });

  tearDownAll(() {
    StudySessionScreen.debugOmitConfettiOverlay = false;
  });

  setUp(() async {
    testTempDir = Directory.systemTemp.createTempSync('nexus_lingua_db_test');
    DatabaseHelper.debugDatabaseAbsolutePath = p.join(testTempDir!.path, 'test.db');
    await DatabaseHelper().closeDatabaseForTesting();
  });

  tearDown(() async {
    await DatabaseHelper().closeDatabaseForTesting();
    DatabaseHelper.debugDatabaseAbsolutePath = null;
    try {
      if (testTempDir != null && testTempDir!.existsSync()) {
        testTempDir!.deleteSync(recursive: true);
      }
    } catch (_) {
      // Windows may briefly lock files; ignore cleanup failure.
    }
    testTempDir = null;
  });

  test('insert profile + card, round-trip via getCardsForProfile', () async {
    final h = DatabaseHelper();
    await h.getDatabase();

    final pid = await h.insertProfile(
      LanguageProfile(
        language: 'TestLang',
        features: const ['gender', 'case_sensitive'],
        createdAt: DateTime.utc(2025, 3, 1),
      ),
    );
    expect(pid, greaterThan(0));

    final card = WordCard(
      profileId: pid,
      lemma: 'lemma',
      translation: 'gloss',
      dueDate: DateTime.utc(2025, 3, 2),
      createdAt: DateTime.utc(2025, 3, 1),
      metadata: const {
        'gender': 'feminine',
        'case_sensitive': true,
      },
    );
    final cid = await h.insertCard(card);
    expect(cid, greaterThan(0));

    final loaded = await h.getCardsForProfile(pid);
    expect(loaded, hasLength(1));
    expect(loaded.single.lemma, 'lemma');
    expect(loaded.single.translation, 'gloss');
    expect(loaded.single.metadata['gender'], 'feminine');
    expect(loaded.single.metadata['case_sensitive'], true);
    expect(loaded.single.id, cid);
  });

  test('getLemmaSetForProfile and CardRepository.insertCard', () async {
    final h = DatabaseHelper();
    await h.getDatabase();
    final pid = await h.insertProfile(
      LanguageProfile(
        language: 'LemmaSet',
        features: const [],
        createdAt: DateTime.utc(2025, 6, 1),
      ),
    );
    final now = DateTime.now();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final due = DateTime.fromMillisecondsSinceEpoch(nowSec * 1000, isUtc: true)
        .toLocal();
    await h.insertCard(
      WordCard(
        profileId: pid,
        lemma: 'alpha',
        translation: 'A',
        dueDate: due,
        createdAt: now,
        metadata: const {},
      ),
    );
    final set = await h.getLemmaSetForProfile(pid);
    expect(set, {'alpha'});

    final repo = CardRepository();
    final id2 = await repo.insertCard(
      WordCard(
        profileId: pid,
        lemma: 'beta',
        translation: 'B',
        dueDate: due,
        createdAt: now,
        metadata: const {},
      ),
    );
    expect(id2, greaterThan(0));
    final set2 = await repo.loadLemmaSetForProfile(pid);
    expect(set2, {'alpha', 'beta'});
  });

  test('exportToJson contains tables', () async {
    final h = DatabaseHelper();
    await h.getDatabase();
    await h.insertProfile(
      LanguageProfile(
        language: 'X',
        features: const [],
        createdAt: DateTime.utc(2025),
      ),
    );
    final json = await h.exportToJson();
    expect(json, contains('language_profiles'));
    expect(json, contains('word_cards'));
    expect(json, contains('review_log'));
  });

  group('CardRepository.commitReview (Phase 3)', () {
    test('persists FSRS state and appends review_log', () async {
      final h = DatabaseHelper();
      await h.getDatabase();
      final pid = await h.insertProfile(
        LanguageProfile(
          language: 'RepoTest',
          features: const [],
          createdAt: DateTime.utc(2025, 4, 1),
        ),
      );
      final past = DateTime.now().subtract(const Duration(days: 1));
      final cid = await h.insertCard(
        WordCard(
          profileId: pid,
          lemma: 'x',
          translation: 'y',
          dueDate: past,
          createdAt: past,
          reviewCount: 0,
          metadata: const {},
        ),
      );
      final loaded = (await h.getCardsForProfile(pid)).single;
      expect(loaded.id, cid);

      const engine = FSRSEngine();
      final now = DateTime.now();
      final updated = engine.schedule(loaded, 3, now);
      expect(updated.reviewCount, 1);
      expect(updated.stability, 2.4);

      final repo = CardRepository();
      await repo.commitReview(
        updatedCard: updated,
        rating: 3,
        stabilityBefore: loaded.stability,
      );

      final db = await h.getDatabase();
      final logs = await db.query('review_log');
      expect(logs, hasLength(1));
      expect(logs.single['card_id'], cid);
      expect(logs.single['rating'], 3);
      expect(logs.single['similarity_r'], isNull);
      expect((logs.single['s_before'] as num).toDouble(), loaded.stability);
      expect((logs.single['s_after'] as num).toDouble(), updated.stability);

      final after = (await h.getCardsForProfile(pid)).single;
      expect(after.stability, updated.stability);
      expect(after.reviewCount, 1);
      expect(after.difficulty, updated.difficulty);
    });

    test('persists optional similarity_r for typist mode', () async {
      final h = DatabaseHelper();
      await h.getDatabase();
      final pid = await h.insertProfile(
        LanguageProfile(
          language: 'TypistRepo',
          features: const [],
          createdAt: DateTime.utc(2025, 4, 2),
        ),
      );
      final past = DateTime.now().subtract(const Duration(days: 1));
      final cid = await h.insertCard(
        WordCard(
          profileId: pid,
          lemma: 'lemma',
          translation: 'gloss',
          dueDate: past,
          createdAt: past,
          reviewCount: 0,
          metadata: const {},
        ),
      );
      final loaded = (await h.getCardsForProfile(pid)).single;
      expect(loaded.id, cid);

      const engine = FSRSEngine();
      final now = DateTime.now();
      final updated = engine.schedule(loaded, 4, now);

      final repo = CardRepository();
      await repo.commitReview(
        updatedCard: updated,
        rating: 4,
        stabilityBefore: loaded.stability,
        similarityR: 0.92,
      );

      final db = await h.getDatabase();
      final logs = await db.query('review_log');
      expect(logs, hasLength(1));
      expect(
        (logs.single['similarity_r'] as num).toDouble(),
        closeTo(0.92, 1e-9),
      );
      expect((logs.single['s_before'] as num).toDouble(), loaded.stability);
      expect((logs.single['s_after'] as num).toDouble(), updated.stability);

      final after = (await h.getCardsForProfile(pid)).single;
      expect(after.stability, updated.stability);
      expect(after.reviewCount, 1);
      expect(after.difficulty, updated.difficulty);
    });
  });

  group('StudySessionScreen (Phase 3)', () {
    testWidgets('material binding sanity', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Text('binding-ok')));
      await tester.pump();
      expect(find.text('binding-ok'), findsOneWidget);
    });

    testWidgets('reveal lemma then Hit persists one review_log row',
        (tester) async {
      final h = DatabaseHelper();
      await h.getDatabase();
      final pid = await h.insertProfile(
        LanguageProfile(
          language: 'WidgetDeck',
          features: const ['gender'],
          createdAt: DateTime.utc(2025, 5, 1),
        ),
      );
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await h.insertCard(
        WordCard(
          profileId: pid,
          lemma: 'alphaLemma',
          translation: 'alphaGloss',
          dueDate: DateTime.fromMillisecondsSinceEpoch(nowSec * 1000),
          createdAt: DateTime.utc(2025, 5, 1),
          reviewCount: 0,
          metadata: const {'gender': 'neuter'},
        ),
      );

      final profile = LanguageProfile(
        id: pid,
        language: 'WidgetDeck',
        features: const ['gender'],
        createdAt: DateTime.utc(2025, 5, 1),
      );

      final now = DateTime.now();
      final dueNow = await h.getDueCards(pid, now);
      expect(dueNow, hasLength(1));
      final repo = _SeededFirstLoadRepository(helper: h, initialDue: dueNow);

      // Force compact study (FsrsRatingRow); default binding width can be ≥840 on some setups.
      // TickerMode off: spinners/confetti must not schedule perpetual frames or pump() can stall.
      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)),
            child: MaterialApp(
              theme: buildNexusTheme(),
              home: StudySessionScreen(
                profile: profile,
                repository: repo,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('alphaLemma'), findsOneWidget);
      await tester.tap(find.text('alphaLemma'));
      for (var i = 0; i < 24; i++) {
        await tester.pump();
      }

      expect(find.text('Hit'), findsOneWidget);
      await tester.tap(find.text('Hit'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 80; i++) {
        await tester.pump();
      }

      final db = await h.getDatabase();
      final logs = await db.query('review_log');
      expect(logs, hasLength(1));
      expect(logs.single['rating'], 3);
    }, skip: _skipStudySessionScreenWidgets);

    testWidgets('wide layout: typist Crit! logs similarity_r = 1',
        (tester) async {
      final h = DatabaseHelper();
      await h.getDatabase();
      final pid = await h.insertProfile(
        LanguageProfile(
          language: 'TypistWidgetDeck',
          features: const ['gender'],
          createdAt: DateTime.utc(2025, 5, 2),
        ),
      );
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await h.insertCard(
        WordCard(
          profileId: pid,
          lemma: 'alphaLemma',
          translation: 'alphaGloss',
          dueDate: DateTime.fromMillisecondsSinceEpoch(nowSec * 1000),
          createdAt: DateTime.utc(2025, 5, 2),
          reviewCount: 0,
          metadata: const {'gender': 'neuter'},
        ),
      );

      final profile = LanguageProfile(
        id: pid,
        language: 'TypistWidgetDeck',
        features: const ['gender'],
        createdAt: DateTime.utc(2025, 5, 2),
      );

      final nowTypist = DateTime.now();
      final dueTypist = await h.getDueCards(pid, nowTypist);
      expect(dueTypist, hasLength(1));
      final repo = _SeededFirstLoadRepository(helper: h, initialDue: dueTypist);

      await tester.pumpWidget(
        TickerMode(
          enabled: false,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: MaterialApp(
              theme: buildNexusTheme(),
              home: StudySessionScreen(
                profile: profile,
                repository: repo,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('alphaLemma'), findsOneWidget);
      await tester.tap(find.text('alphaLemma'));
      for (var i = 0; i < 24; i++) {
        await tester.pump();
      }

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'alphalemma');
      await tester.tap(find.text('Submit answer'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 80; i++) {
        await tester.pump();
      }

      final db = await h.getDatabase();
      final logs = await db.query('review_log');
      expect(logs, hasLength(1));
      expect(logs.single['rating'], 4);
      expect(
        (logs.single['similarity_r'] as num).toDouble(),
        closeTo(1.0, 1e-9),
      );
    }, skip: _skipStudySessionScreenWidgets);
  });
}

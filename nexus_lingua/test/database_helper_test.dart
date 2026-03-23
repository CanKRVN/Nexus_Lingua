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

/// Deterministic in-memory repository for StudySessionScreen widget tests.
final class _WidgetTestRepository extends CardRepository {
  _WidgetTestRepository({
    required this.profileId,
    required List<WordCard> initialDue,
  }) : _dueQueue = List<WordCard>.from(initialDue);

  final int profileId;
  List<WordCard> _dueQueue;
  final List<({WordCard card, int rating, double? similarityR})> commits = [];

  @override
  Future<List<WordCard>> loadDueCardsForProfile(int pid, DateTime now) async {
    if (pid != profileId) return const <WordCard>[];
    return List<WordCard>.from(_dueQueue);
  }

  @override
  Future<void> commitReview({
    required WordCard updatedCard,
    required int rating,
    required double stabilityBefore,
    double? similarityR,
  }) async {
    commits.add((card: updatedCard, rating: rating, similarityR: similarityR));
    _dueQueue = _dueQueue.where((c) => c.id != updatedCard.id).toList();
  }
}

/// `flutter_tester` on Windows can stall on `pump()` with full [StudySessionScreen] + FFI DB.
/// Linux CI (`.github/workflows/flutter_ci.yml`) runs these tests unskipped.
/// To attempt them locally on Windows: `FORCE_STUDY_WIDGET_TESTS=true flutter test ...` (may hang).
bool get _skipStudySessionScreenWidgets {
  if (!Platform.isWindows) return false;
  return Platform.environment['FORCE_STUDY_WIDGET_TESTS'] != 'true';
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 60,
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for widget: $finder');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// One temp dir per test; deleted in [tearDown] after DB close.
  Directory? testTempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
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
    expect(json, contains('app_preferences'));
  });

  test('importProfilesAndCardsFromJson restores app_preferences when present', () async {
    final h = DatabaseHelper();
    await h.getDatabase();
    final pid = await h.insertProfile(
      LanguageProfile(
        language: 'PrefImport',
        features: const [],
        createdAt: DateTime.utc(2025),
      ),
    );
    await h.insertCard(
      WordCard(
        profileId: pid,
        lemma: 'one',
        translation: 'eins',
        dueDate: DateTime.utc(2025),
        createdAt: DateTime.utc(2025),
        metadata: const {},
      ),
    );
    await h.setAppPreference('theme_mode', 'dark');
    final exported = await h.exportToJson();
    await h.closeDatabaseForTesting();
    DatabaseHelper.debugDatabaseAbsolutePath = p.join(
      testTempDir!.path,
      'import_prefs.db',
    );
    final h2 = DatabaseHelper();
    await h2.getDatabase();
    await h2.setAppPreference('theme_mode', 'light');
    expect(await h2.getAppPreference('theme_mode'), 'light');
    final r = await h2.importProfilesAndCardsFromJson(exported);
    expect(r.profiles, 1);
    expect(r.cards, 1);
    expect(r.preferences, greaterThanOrEqualTo(1));
    expect(await h2.getAppPreference('theme_mode'), 'dark');
  });

  test('debugFastForward subtracts days so future cards become due', () async {
    final h = DatabaseHelper();
    await h.getDatabase();
    final ref = DateTime.utc(2025, 6, 15, 12);
    final refSec = ref.millisecondsSinceEpoch ~/ 1000;
    final futureSec = refSec + 3 * 86400;
    final futureDue = DateTime.fromMillisecondsSinceEpoch(
      futureSec * 1000,
      isUtc: true,
    ).toLocal();

    final pid = await h.insertProfile(
      LanguageProfile(
        language: 'FF',
        features: const [],
        createdAt: ref,
      ),
    );

    for (var i = 0; i < 5; i++) {
      await h.insertCard(
        WordCard(
          profileId: pid,
          lemma: 'w$i',
          translation: 't',
          dueDate: futureDue,
          createdAt: ref,
          metadata: const {},
        ),
      );
    }

    final dueBefore = await h.getDueCards(pid, ref);
    expect(dueBefore, isEmpty);

    final updated = await h.debugFastForward(pid, 7);
    expect(updated, 5);

    final dueAfter = await h.getDueCards(pid, ref);
    expect(dueAfter, hasLength(5));
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
    // These widget tests intentionally use _WidgetTestRepository instead of a
    // real SQLite-backed repository to avoid CI flakes from DB/file locks and
    // timer-driven settles. Coverage focus is interaction flow + review payload.
    testWidgets('material binding sanity', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Text('binding-ok')));
      await tester.pump();
      expect(find.text('binding-ok'), findsOneWidget);
    });

    testWidgets('reveal lemma then Hit persists one review_log row',
        (tester) async {
      final pid = 101;
      final profile = LanguageProfile(
        id: pid,
        language: 'WidgetDeck',
        features: const ['gender'],
        createdAt: DateTime.utc(2025, 5, 1),
      );
      final dueNow = <WordCard>[
        WordCard(
          id: 1,
          profileId: pid,
          lemma: 'alphaLemma',
          translation: 'alphaGloss',
          dueDate: DateTime.now(),
          createdAt: DateTime.utc(2025, 5, 1),
          reviewCount: 0,
          metadata: const {'gender': 'neuter'},
        ),
      ];
      final repo = _WidgetTestRepository(profileId: pid, initialDue: dueNow);

      // Force compact study (FsrsRatingRow); default binding width can be ≥840 on some setups.
      // TickerMode off: spinners must not schedule perpetual frames or pump() can stall.
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
      await _pumpUntilFound(tester, find.text('alphaLemma'));
      await tester.tap(find.text('alphaLemma'));
      await _pumpUntilFound(tester, find.text('Hit'));

      await tester.tap(find.text('Hit'));
      await _pumpUntilFound(tester, find.text('No due cards'));
      expect(repo.commits, hasLength(1));
      expect(repo.commits.single.rating, 3);
      expect(repo.commits.single.similarityR, isNull);
    }, skip: _skipStudySessionScreenWidgets);

    testWidgets('wide layout: typist Crit! logs similarity_r = 1',
        (tester) async {
      final pid = 102;
      final profile = LanguageProfile(
        id: pid,
        language: 'TypistWidgetDeck',
        features: const ['gender'],
        createdAt: DateTime.utc(2025, 5, 2),
      );
      final dueTypist = <WordCard>[
        WordCard(
          id: 2,
          profileId: pid,
          lemma: 'alphaLemma',
          translation: 'alphaGloss',
          dueDate: DateTime.now(),
          createdAt: DateTime.utc(2025, 5, 2),
          reviewCount: 0,
          metadata: const {'gender': 'neuter'},
        ),
      ];
      final repo = _WidgetTestRepository(profileId: pid, initialDue: dueTypist);

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
      await _pumpUntilFound(tester, find.text('alphaLemma'));
      await _pumpUntilFound(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'alphagloss');
      await tester.tap(find.text('Submit'));
      await _pumpUntilFound(tester, find.text('Crit!'));
      await _pumpUntilFound(tester, find.text('Next'));
      await tester.tap(find.text('Next'));
      await _pumpUntilFound(tester, find.text('No due cards'));
      expect(repo.commits, hasLength(1));
      expect(repo.commits.single.rating, 4);
      expect(repo.commits.single.similarityR, closeTo(1.0, 1e-9));
    }, skip: _skipStudySessionScreenWidgets);
  });
}

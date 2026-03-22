import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/evaluator/evaluation_result.dart';
import '../../core/evaluator/similarity_evaluator.dart';
import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../../core/srs/fsrs_engine.dart';
import '../../shared/layout/study_layout.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/flashcard_widget.dart';
import '../../shared/widgets/fsrs_rating_row.dart';

/// Study session: due queue, reveal lemma → answer, FSRS + `review_log`.
///
/// Stateful controller; child widgets stay stateless (`.cursorrules` §3.4).
class StudySessionScreen extends StatefulWidget {
  /// Creates a study session for [profile].
  const StudySessionScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  /// Active deck profile (must have [LanguageProfile.id] set).
  final LanguageProfile profile;

  /// Data access via [CardRepository] only (no direct DB helper from UI).
  final CardRepository repository;

  /// VM widget tests only: the confetti overlay can prevent the test binding
  /// from idling. Production keeps this `false`.
  static bool debugOmitConfettiOverlay = false;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  static const FSRSEngine _engine = FSRSEngine();
  static const SimilarityEvaluator _evaluator = SimilarityEvaluator();

  final TextEditingController _answerController = TextEditingController();
  ConfettiController? _confettiController;

  List<WordCard> _queue = [];
  bool _loading = true;
  bool _saving = false;
  bool _revealed = false;
  bool _glitching = false;
  String? _error;
  EvaluationResult? _typistFeedback;

  @override
  void initState() {
    super.initState();
    if (!StudySessionScreen.debugOmitConfettiOverlay) {
      _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    }
    // Defer load: calling setState from _reloadQueue must not run synchronously
    // during initState (widget tests / binding can hang otherwise).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadQueue());
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _confettiController?.dispose();
    super.dispose();
  }

  Future<void> _reloadQueue({bool showLoading = true}) async {
    final id = widget.profile.id;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Profile has no id';
        _queue = [];
      });
      return;
    }
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list =
          await widget.repository.loadDueCardsForProfile(id, DateTime.now());
      if (!mounted) return;
      setState(() {
        _queue = list;
        _loading = false;
        _revealed = false;
        _typistFeedback = null;
        _answerController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _queue = [];
      });
    }
  }

  WordCard? get _current => _queue.isEmpty ? null : _queue.first;

  /// When false (e.g. widget tests with [TickerMode] disabled), skip confetti
  /// and artificial [Future.delayed] so fake-async tests do not hang.
  bool get _animationsEnabled => TickerMode.valuesOf(context).enabled;

  void _maybePlayConfetti() {
    final c = _confettiController;
    if (c != null && _animationsEnabled) {
      c.play();
    }
  }

  Color _colorForLabel(String label) {
    switch (label) {
      case 'Crit!':
        return AppColors.feedbackCrit;
      case 'Hit':
        return AppColors.feedbackHit;
      case 'Hard':
        return AppColors.feedbackHard;
      default:
        return AppColors.feedbackMiss;
    }
  }

  Future<void> _persistReview(int rating, {double? similarityR}) async {
    final card = _current;
    if (card == null || card.id == null) return;

    final sBefore = card.stability;
    final now = DateTime.now();

    try {
      final updated = _engine.schedule(card, rating, now);
      await widget.repository.commitReview(
        updatedCard: updated,
        rating: rating,
        stabilityBefore: sBefore,
        similarityR: similarityR,
      );
      if (!mounted) return;
      await _reloadQueue(showLoading: false);
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review failed: $e'),
          backgroundColor: AppColors.feedbackMiss,
        ),
      );
    }
  }

  Future<void> _onRated(int rating, {double? similarityR}) async {
    final card = _current;
    if (card == null || card.id == null || _saving) return;

    setState(() => _saving = true);

    if (rating == 4) {
      _maybePlayConfetti();
    }

    if (rating == 1) {
      setState(() => _glitching = true);
      if (_animationsEnabled) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (!mounted) return;
      setState(() => _glitching = false);
    }

    await _persistReview(rating, similarityR: similarityR);
  }

  Future<void> _submitTypistAnswer() async {
    final card = _current;
    if (card == null || card.id == null || _saving) return;

    final result = _evaluator.evaluate(_answerController.text, card);
    setState(() {
      _typistFeedback = result;
      _saving = true;
    });

    if (result.fsrsRating == 4) {
      _maybePlayConfetti();
    }
    if (result.fsrsRating == 1) {
      setState(() => _glitching = true);
    }

    if (_animationsEnabled) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted) return;
    setState(() {
      _typistFeedback = null;
      _glitching = false;
    });

    await _persistReview(result.fsrsRating, similarityR: result.ratio);
  }

  @override
  Widget build(BuildContext context) {
    final pid = widget.profile.id;
    final mainBody = _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.accentCyan),
          )
        : pid == null
            ? Center(
                child: Text(
                  _error ?? 'Invalid profile',
                  style: const TextStyle(color: AppColors.feedbackMiss),
                ),
              )
            : _error != null && _queue.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.feedbackMiss),
                      ),
                    ),
                  )
                : _current == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.accentGreen,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No due cards',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Everything scheduled is in the future.',
                              style: TextStyle(color: AppColors.textSubtext),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      )
                    : _StudyCardBody(
                        profile: widget.profile,
                        card: _current!,
                        totalDue: _queue.length,
                        revealed: _revealed,
                        saving: _saving,
                        typistMode: StudyLayout.useTypistMode(context),
                        answerController: _answerController,
                        typistFeedback: _typistFeedback,
                        glitching: _glitching,
                        feedbackColorForLabel: _colorForLabel,
                        onReveal: () => setState(() => _revealed = true),
                        onRatedAsync: _onRated,
                        onSubmitTypist: _submitTypistAnswer,
                      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study'),
        actions: [
          IconButton(
            tooltip: 'Refresh due',
            onPressed: _loading || _saving ? null : _reloadQueue,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: mainBody),
          if (!StudySessionScreen.debugOmitConfettiOverlay)
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController!,
                  blastDirectionality: BlastDirectionality.explosive,
                  blastDirection: -math.pi / 2,
                  emissionFrequency: 0.08,
                  numberOfParticles: 22,
                  maxBlastForce: 22,
                  minBlastForce: 8,
                  gravity: 0.12,
                  colors: const [
                    AppColors.accentCyan,
                    AppColors.accentMagenta,
                    AppColors.accentGreen,
                    AppColors.feedbackCrit,
                    AppColors.feedbackHit,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StudyCardBody extends StatelessWidget {
  const _StudyCardBody({
    required this.profile,
    required this.card,
    required this.totalDue,
    required this.revealed,
    required this.saving,
    required this.typistMode,
    required this.answerController,
    required this.typistFeedback,
    required this.glitching,
    required this.feedbackColorForLabel,
    required this.onReveal,
    required this.onRatedAsync,
    required this.onSubmitTypist,
  });

  final LanguageProfile profile;
  final WordCard card;
  final int totalDue;
  final bool revealed;
  final bool saving;
  final bool typistMode;
  final TextEditingController answerController;
  final EvaluationResult? typistFeedback;
  final bool glitching;
  final Color Function(String label) feedbackColorForLabel;
  final VoidCallback onReveal;
  final Future<void> Function(int rating, {double? similarityR}) onRatedAsync;
  final Future<void> Function() onSubmitTypist;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        glitching ? AppColors.feedbackMiss : AppColors.borderNeutral;
    final borderWidth = glitching ? 3.0 : 2.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              totalDue <= 1 ? '1 card due' : '1 / $totalDue due in queue',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSubtext,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: revealed
                        ? FlashcardWidget(card: card, profile: profile)
                        : _PromptCard(lemma: card.lemma, onReveal: onReveal),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (revealed) ...[
              if (typistMode) ...[
                if (typistFeedback != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      typistFeedback!.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: feedbackColorForLabel(typistFeedback!.label),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                TextField(
                  controller: answerController,
                  enabled: !saving,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!saving) unawaited(onSubmitTypist());
                  },
                  style: const TextStyle(color: AppColors.textBody),
                  decoration: InputDecoration(
                    labelText: 'Type the lemma',
                    labelStyle: const TextStyle(color: AppColors.textSubtext),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.accentCyan),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppColors.accentCyan,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textDisabled.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      saving ? null : () => unawaited(onSubmitTypist()),
                  child: const Text('Submit answer'),
                ),
              ] else
                FsrsRatingRow(
                  onRated: (r) => unawaited(onRatedAsync(r)),
                  busy: saving,
                ),
              if (saving)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ),
            ] else
              Text(
                typistMode
                    ? 'Reveal the prompt, then type the lemma.'
                    : 'Reveal the answer to rate this card.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSubtext,
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Front side: lemma only, tap to reveal (PRD front/back flow).
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.lemma,
    required this.onReveal,
  });

  final String lemma;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReveal,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.transparent, width: 2),
            color: AppColors.surfaceGlass,
          ),
          child: Column(
            children: [
              Text(
                lemma,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBody,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Tap to reveal answer',
                style: TextStyle(color: AppColors.accentCyan, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

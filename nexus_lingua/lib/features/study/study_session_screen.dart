import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/card_repository.dart';
import '../../core/evaluator/evaluation_result.dart';
import '../../core/evaluator/similarity_evaluator.dart';
import '../../core/models/language_profile.dart';
import '../../core/models/study_direction.dart';
import '../../core/models/word_card.dart';
import '../../core/srs/fsrs_due_preview.dart';
import '../../core/srs/fsrs_engine.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/layout/study_layout.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_motion.dart';
import '../../shared/widgets/fsrs_rating_row.dart';
import '../../shared/widgets/mastery_badge.dart';
import '../../shared/widgets/rotating_green_border.dart';
import '../../shared/widgets/spectral/crit_orbit_burst.dart';
import '../../shared/widgets/spectral/fsrs_hud_nodes.dart';
import '../../shared/widgets/spectral/study_hud_strip.dart';
import '../../shared/widgets/nexus_glow_filled_button.dart';
import '../../shared/widgets/study_answer_field.dart';
import '../../shared/widgets/study_mastery_card.dart';

/// Study session: compact = tap reveal + FSRS row; typist = lemma prompt, type translation, flip reveal.
///
/// Stateful controller; child widgets stay stateless (`.cursorrules` §3.4).
class StudySessionScreen extends StatefulWidget {
  /// Creates a study session for [profile].
  const StudySessionScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.sMax = 365,
    this.effectsEnabled = true,
    this.ratingDisplayStyle = RatingDisplayStyle.labels,
    this.studyDirection = StudyDirection.targetToKnown,
  });

  /// Active deck profile (must have [LanguageProfile.id] set).
  final LanguageProfile profile;

  /// Data access via [CardRepository] only (no direct DB helper from UI).
  final CardRepository repository;

  /// XP bar normalization (PRD §7.4 / Settings).
  final double sMax;

  /// Flip, beam, glitch when false (Settings).
  final bool effectsEnabled;

  /// Compact row presentation when not in typist mode.
  final RatingDisplayStyle ratingDisplayStyle;

  /// Typist: prompt side vs answer side ([StudyDirection.targetToKnown] = see target, type known).
  final StudyDirection studyDirection;

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen>
    with TickerProviderStateMixin {
  static const FSRSEngine _engine = FSRSEngine();
  static const SimilarityEvaluator _evaluator = SimilarityEvaluator();

  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  final FocusNode _advanceFocusNode = FocusNode();

  late AnimationController _flipController;
  late CurvedAnimation _flipCurved;

  List<WordCard> _queue = [];
  bool _loading = true;
  bool _saving = false;
  bool _revealed = false;
  bool _glitching = false;
  String? _error;
  EvaluationResult? _typistFeedback;
  EvaluationResult? _pendingTypistResult;
  bool _typistAwaitingAdvance = false;
  bool _successBeam = false;

  /// Snapshot for thin top progress (session reviews / initial due count).
  int _sessionInitialDue = 0;
  int _sessionReviewsCompleted = 0;

  DateTime? _sessionStartedAt;
  Timer? _sessionClock;
  int _critBurstGen = 0;

  double get _sessionProgress {
    if (_sessionInitialDue <= 0) return 0;
    return (_sessionReviewsCompleted / _sessionInitialDue).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: NexusMotion.layout,
    );
    _flipCurved = CurvedAnimation(
      parent: _flipController,
      curve: NexusMotion.layoutSymmetric,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadQueue());
    });
  }

  @override
  void dispose() {
    _sessionClock?.cancel();
    _answerController.dispose();
    _answerFocusNode.dispose();
    _advanceFocusNode.dispose();
    _flipCurved.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _focusAnswerInputIfVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final typist = StudyLayout.useTypistMode(context);
      final shouldFocus = typist &&
          _current != null &&
          !_revealed &&
          !_saving &&
          !_flipController.isAnimating &&
          !_typistAwaitingAdvance;
      if (!shouldFocus) return;
      _advanceFocusNode.unfocus();
      _answerFocusNode.requestFocus();
    });
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
      _sessionClock?.cancel();
      _sessionClock = null;
      _sessionStartedAt = null;
      setState(() {
        _loading = true;
        _error = null;
        _sessionInitialDue = 0;
        _sessionReviewsCompleted = 0;
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
        _pendingTypistResult = null;
        _typistAwaitingAdvance = false;
        _successBeam = false;
        _answerController.clear();
        _flipController.reset();
        if (_sessionInitialDue == 0 && list.isNotEmpty) {
          _sessionInitialDue = list.length;
        }
        if (list.isNotEmpty && _sessionStartedAt == null) {
          _sessionStartedAt = DateTime.now();
          _sessionClock ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
        }
      });
      _focusAnswerInputIfVisible();
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

  bool get _animationsEnabled => TickerMode.valuesOf(context).enabled;

  void _startSuccessBeam() {
    if (!widget.effectsEnabled || !_animationsEnabled) return;
    setState(() => _successBeam = true);
  }

  void _stopSuccessBeam() {
    if (mounted) setState(() => _successBeam = false);
  }

  Color _colorForLabel(String label) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    switch (label) {
      case 'Crit!':
        return scheme.tertiary;
      case 'Hit':
        return ex.feedbackHit;
      case 'Hard':
        return ex.feedbackHard;
      default:
        return scheme.error;
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
      _sessionReviewsCompleted++;
      await _reloadQueue(showLoading: false);
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Review failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _onRated(int rating, {double? similarityR}) async {
    final card = _current;
    if (card == null || card.id == null || _saving) return;

    setState(() => _saving = true);

    if (rating == 4) {
      _startSuccessBeam();
    }

    if (rating == 1 && widget.effectsEnabled) {
      setState(() => _glitching = true);
      if (_animationsEnabled) {
        await Future<void>.delayed(NexusMotion.feedbackHold);
      }
      if (!mounted) return;
      setState(() => _glitching = false);
    }

    await _persistReview(rating, similarityR: similarityR);
    _stopSuccessBeam();
  }

  Future<void> _submitTypistAnswer() async {
    final card = _current;
    if (card == null ||
        card.id == null ||
        _saving ||
        _typistAwaitingAdvance) {
      return;
    }

    final result = _evaluator.evaluateTypistRecall(
      _answerController.text,
      card,
      widget.studyDirection,
    );

    setState(() => _saving = true);

    if (_animationsEnabled && widget.effectsEnabled) {
      // Start mid-flip so we never flash the prompt (front) again; `forward(from: 0)` resets t=0.
      _flipController.value = 0.5;
      await _flipController.forward();
      if (!mounted) return;
    }

    if (result.fsrsRating == 4) {
      _startSuccessBeam();
    }
    if (result.fsrsRating == 1 && widget.effectsEnabled) {
      setState(() => _glitching = true);
      if (_animationsEnabled) {
        await Future<void>.delayed(NexusMotion.feedbackHold);
      }
      if (!mounted) return;
      setState(() => _glitching = false);
    }

    if (!mounted) return;
    final isPerfectCrit =
        result.label == 'Crit!' && result.ratio >= 1.0 - 1e-9;
    setState(() {
      if (isPerfectCrit) _critBurstGen++;
      _revealed = true;
      _typistFeedback = result;
      _pendingTypistResult = result;
      _typistAwaitingAdvance = true;
      _saving = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _typistAwaitingAdvance) {
        _advanceFocusNode.requestFocus();
      }
    });
  }

  Future<void> _finalizeTypistAdvance() async {
    final pending = _pendingTypistResult;
    if (!_typistAwaitingAdvance || pending == null || _saving) return;

    setState(() {
      _typistAwaitingAdvance = false;
      _saving = true;
    });

    await _persistReview(pending.fsrsRating, similarityR: pending.ratio);
    _stopSuccessBeam();
    if (mounted) {
      setState(() {
        _pendingTypistResult = null;
        _typistFeedback = null;
      });
    }
  }

  /// Debug-only control: see [kDebugMode] overlay in [build].
  Future<void> _debugFastForward7Days() async {
    final id = widget.profile.id;
    if (id == null || _loading || _saving || _typistAwaitingAdvance) return;
    try {
      final n = await widget.repository.debugFastForwardDays(id, 7);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fast-forward 7d: adjusted $n card(s).'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _reloadQueue(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fast-forward failed: $e')),
      );
    }
  }

  Future<void> _debugMarkAllDueNow() async {
    final id = widget.profile.id;
    if (id == null || _loading || _saving || _typistAwaitingAdvance) return;
    try {
      final n = await widget.repository.debugMarkAllCardsDueNowForProfile(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debug: marked $n card(s) due now.'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _reloadQueue(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debug reset failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final pid = widget.profile.id;
    final typist = StudyLayout.useTypistMode(context);
    final mainBody = _loading
        ? Center(
            child: CircularProgressIndicator(color: scheme.primary),
          )
        : pid == null
            ? Center(
                child: Text(
                  _error ?? 'Invalid profile',
                  style: TextStyle(color: scheme.error),
                ),
              )
            : _error != null && _queue.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  )
                : _current == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: scheme.tertiary,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No due cards',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Everything scheduled is in the future.',
                              style: TextStyle(color: ex.textSubtext),
                            ),
                            const SizedBox(height: 24),
                            NexusGlowFilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      )
                    : Focus(
                        focusNode: _advanceFocusNode,
                        onKeyEvent: (node, event) {
                          if (!_typistAwaitingAdvance) {
                            return KeyEventResult.ignored;
                          }
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter) {
                            unawaited(_finalizeTypistAdvance());
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: _StudyCardBody(
                          profile: widget.profile,
                          card: _current!,
                          studyDirection: widget.studyDirection,
                          revealed: _revealed,
                          saving: _saving,
                          typistAwaitingAdvance: _typistAwaitingAdvance,
                          typistMode: typist,
                          answerController: _answerController,
                          answerFocusNode: _answerFocusNode,
                          typistFeedback: _typistFeedback,
                          glitching: _glitching,
                          successBeam: _successBeam,
                          flipT: _flipCurved,
                          flipAnimating: _flipController.isAnimating,
                          feedbackColorForLabel: _colorForLabel,
                          ratingDisplayStyle: widget.ratingDisplayStyle,
                          onReveal: () => setState(() => _revealed = true),
                          onRatedAsync: _onRated,
                          onSubmitTypist: _submitTypistAnswer,
                          onTypistNext: _finalizeTypistAdvance,
                          critBurstKey: _critBurstGen,
                        ),
                      );

    final body = mainBody;

    final tierLabel = _current != null
        ? masteryTierStyle(masteryTierForStability(_current!.stability)).$1
        : '—';
    final elapsed = _sessionStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(_sessionStartedAt!);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_loading && pid != null)
          StudyHudStrip(
            elapsed: elapsed,
            sessionProgress: _sessionProgress,
            dueRemaining: _queue.length,
            tierLabel: tierLabel,
          ),
        Expanded(child: body),
      ],
    );

    return NexusPageScaffold(
      navigatorContext: context,
      repository: widget.repository,
      activeProfile: widget.profile,
      title: const Text('Study'),
      actions: [
        IconButton(
          tooltip: 'Refresh due',
          onPressed: _loading || _saving || _typistAwaitingAdvance
              ? null
              : _reloadQueue,
          icon: const Icon(Icons.refresh),
        ),
        if (kDebugMode && pid != null)
          IconButton(
            tooltip: 'Fast Forward 7 Days (all cards in deck)',
            onPressed: _loading || _saving || _typistAwaitingAdvance
                ? null
                : () => unawaited(_debugFastForward7Days()),
            icon: const Icon(Icons.fast_forward),
          ),
        if (kDebugMode && pid != null)
          IconButton(
            tooltip: 'Debug: set all cards due now',
            onPressed: _loading || _saving || _typistAwaitingAdvance
                ? null
                : _debugMarkAllDueNow,
            icon: const Icon(Icons.bug_report_outlined),
          ),
      ],
      body: content,
    );
  }
}

class _StudyCardBody extends StatelessWidget {
  const _StudyCardBody({
    required this.profile,
    required this.card,
    required this.studyDirection,
    required this.revealed,
    required this.saving,
    required this.typistAwaitingAdvance,
    required this.typistMode,
    required this.answerController,
    required this.answerFocusNode,
    required this.typistFeedback,
    required this.glitching,
    required this.successBeam,
    required this.flipT,
    required this.flipAnimating,
    required this.feedbackColorForLabel,
    required this.ratingDisplayStyle,
    required this.onReveal,
    required this.onRatedAsync,
    required this.onSubmitTypist,
    required this.onTypistNext,
    required this.critBurstKey,
  });

  final LanguageProfile profile;
  final WordCard card;
  final StudyDirection studyDirection;
  final bool revealed;
  final bool saving;
  final bool typistAwaitingAdvance;
  final bool typistMode;
  final TextEditingController answerController;
  final FocusNode answerFocusNode;
  final EvaluationResult? typistFeedback;
  final bool glitching;
  final bool successBeam;
  /// Eased 0–1 progress for the 3D flip (slow–fast–slow).
  final Animation<double> flipT;
  final bool flipAnimating;
  final Color Function(String label) feedbackColorForLabel;
  final RatingDisplayStyle ratingDisplayStyle;
  final VoidCallback onReveal;
  final Future<void> Function(int rating, {double? similarityR}) onRatedAsync;
  final Future<void> Function() onSubmitTypist;
  final Future<void> Function() onTypistNext;
  final int critBurstKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    final showTypistInput = typistMode &&
        !revealed &&
        !flipAnimating &&
        !saving;

    final answerHint = studyDirection == StudyDirection.targetToKnown
        ? (profile.knownLanguage.trim().isEmpty
            ? 'Type the gloss…'
            : 'Type in ${profile.knownLanguage}…')
        : 'Type in ${profile.language}…';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: typistMode
                  ? _buildTypistCardArea(context)
                  : LayoutBuilder(
                      builder: (context, c) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: revealed
                              ? Center(
                                  child: SingleChildScrollView(
                                    child: RotatingGreenBorder(
                                      active: successBeam,
                                      spectralOutline: true,
                                      child: StudyMasteryCard(
                                        card: card,
                                        glitchBorder: glitching,
                                      ),
                                    ),
                                  ),
                                )
                              : _StudyTapPromptCard(
                                  prompt: studyDirection ==
                                          StudyDirection.targetToKnown
                                      ? card.targetSurface
                                      : card.translation,
                                  glitchBorder: glitching,
                                  onReveal: onReveal,
                                ),
                        );
                      },
                    ),
            ),
            if (typistMode && showTypistInput) ...[
              StudyAnswerField(
                controller: answerController,
                focusNode: answerFocusNode,
                enabled: !saving,
                hintText: answerHint,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onSubmitted: (_) {
                  if (!saving) unawaited(onSubmitTypist());
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      saving ? null : () => unawaited(onSubmitTypist()),
                  child: Text(
                    'Submit',
                    style: TextStyle(
                      color: saving
                          ? ex.textDisabled
                          : scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (typistMode && flipAnimating)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            if (typistMode && revealed) ...[
              if (typistFeedback != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Builder(
                    builder: (context) {
                      final perfectCrit = typistFeedback!.label == 'Crit!' &&
                          typistFeedback!.ratio >= 1.0 - 1e-9;
                      final labelWidget = Text(
                        typistFeedback!.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: feedbackColorForLabel(
                                typistFeedback!.label,
                              ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      );
                      return perfectCrit
                          ? CritOrbitBurst(
                              key: ValueKey(critBurstKey),
                              active: true,
                              child: labelWidget,
                            )
                          : labelWidget;
                    },
                  ),
                ),
              if (typistAwaitingAdvance) ...[
                Text(
                  'Enter — or continue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ex.textSubtext.withValues(alpha: 0.8),
                      ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed:
                        saving ? null : () => unawaited(onTypistNext()),
                    child: Text(
                      'Next',
                      style: TextStyle(
                        color: saving
                            ? ex.textDisabled
                            : scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (!typistMode && revealed) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final dues =
                      const FSRSEngine().previewDueDates(card, now);
                  final lines = [
                    for (final d in dues) formatFsrsDuePreview(now, d),
                  ];
                  return FsrsHudNodes(
                    onRated: (r) => unawaited(onRatedAsync(r)),
                    busy: saving,
                    displayStyle: ratingDisplayStyle,
                    schedulePreviewLines: lines,
                  );
                },
              ),
            ],
            if (saving &&
                (!typistMode || (revealed && !typistAwaitingAdvance)))
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypistCardArea(BuildContext context) {
    final prompt = studyDirection == StudyDirection.targetToKnown
        ? card.targetSurface
        : card.translation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 400.0;
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        const pad = 6.0;
        final innerH = (h - 2 * pad).clamp(120.0, double.infinity);
        final innerW = (w - 2 * pad).clamp(0.0, double.infinity);

        if (revealed) {
          return Padding(
            padding: const EdgeInsets.all(pad),
            child: Center(
              child: SingleChildScrollView(
                child: RotatingGreenBorder(
                  active: successBeam,
                  spectralOutline: true,
                  child: StudyMasteryCard(
                    card: card,
                    glitchBorder: glitching,
                    animateTranslationReveal: false,
                  ),
                ),
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: flipT,
          builder: (context, _) {
            final t = flipT.value;
            final angle = t * math.pi;
            final showFront = t < 0.5;

            final Widget face = showFront
                ? SizedBox(
                    height: innerH,
                    width: innerW,
                    child: StudyPromptHero(
                      prompt: prompt,
                      glitchBorder: glitching,
                    ),
                  )
                : SizedBox(
                    height: innerH,
                    width: innerW,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: StudyMasteryCard(
                        card: card,
                        glitchBorder: glitching,
                        animateTranslationReveal: false,
                      ),
                    ),
                  );

            return Padding(
              padding: const EdgeInsets.all(pad),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(showFront ? angle : math.pi - angle),
                    child: face,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact: full-area tap target with shared hero shell.
class _StudyTapPromptCard extends StatelessWidget {
  const _StudyTapPromptCard({
    required this.prompt,
    required this.onReveal,
    this.glitchBorder = false,
  });

  final String prompt;
  final VoidCallback onReveal;
  final bool glitchBorder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReveal,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: StudyPromptHero(
                    prompt: prompt,
                    glitchBorder: glitchBorder,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Tap to reveal',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.75),
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

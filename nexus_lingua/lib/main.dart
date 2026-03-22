import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/database/card_repository.dart';
import 'core/models/language_profile.dart';
import 'core/models/word_card.dart';
import 'features/sentence_decoder/sentence_decoder_screen.dart';
import 'features/study/study_session_screen.dart';
import 'shared/layout/nexus_breakpoints.dart';
import 'shared/layout/nexus_responsive_shell.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/flashcard_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NexusLinguaApp());
}

/// Root app: Cyber-Minimalist shell + persistence bootstrap.
class NexusLinguaApp extends StatelessWidget {
  /// Creates the app.
  const NexusLinguaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Lingua',
      theme: buildNexusTheme(),
      home: const _BootstrapHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _BootstrapHome extends StatefulWidget {
  const _BootstrapHome();

  @override
  State<_BootstrapHome> createState() => _BootstrapHomeState();
}

class _BootstrapHomeState extends State<_BootstrapHome> {
  final _repo = CardRepository();
  late Future<_BootstrapData> _future;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BootstrapData> _load() async {
    final message = await _repo.bootstrapPersistence();
    final profile = await _repo.firstProfile();
    final cards = await _repo.loadFirstProfileCards();
    var dueCount = 0;
    final pid = profile?.id;
    if (pid != null) {
      dueCount =
          (await _repo.loadDueCardsForProfile(pid, DateTime.now())).length;
    }
    return _BootstrapData(
      message: message,
      profile: profile,
      cards: cards,
      dueCount: dueCount,
    );
  }

  void _openStudySession(BuildContext context, LanguageProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StudySessionScreen(
          profile: profile,
          repository: _repo,
        ),
      ),
    );
  }

  void _openSentenceDecoder(BuildContext context, LanguageProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SentenceDecoderScreen(
          profile: profile,
          repository: _repo,
        ),
      ),
    );
  }

  WordCard? _selectedCard(List<WordCard> cards) {
    if (cards.isEmpty) return null;
    final i = _selectedIndex.clamp(0, cards.length - 1);
    return cards[i];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapData>(
      future: _future,
      builder: (context, snapshot) {
        final canStudy = snapshot.hasData && snapshot.data!.profile?.id != null;
        final dueCount = snapshot.data?.dueCount ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nexus Lingua'),
            actions: [
              if (canStudy)
                TextButton.icon(
                  onPressed: () => _openStudySession(
                    context,
                    snapshot.data!.profile!,
                  ),
                  icon: const Icon(Icons.school_outlined, size: 20),
                  label: Text(
                    'Study ($dueCount)',
                    style: const TextStyle(color: AppColors.textBody),
                  ),
                ),
            ],
          ),
          body: _buildBody(context, snapshot),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncSnapshot<_BootstrapData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentCyan),
      );
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: AppColors.accentMagenta),
          ),
        ),
      );
    }
    final data = snapshot.data!;
    final profile = data.profile;
    final cards = data.cards;
    final selected = _selectedCard(cards);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= NexusBreakpoints.wideLayoutMinWidthLp;

        final mainScroll = RefreshIndicator(
          color: AppColors.accentCyan,
          onRefresh: () async {
            setState(() {
              _future = _load();
            });
            await _future;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      data.message,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (profile != null)
                      Text(
                        'Layout: ${wide ? "wide (≥${NexusBreakpoints.wideLayoutMinWidthLp} lp)" : "compact"}',
                        style: const TextStyle(
                          color: AppColors.textSubtext,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (profile != null && selected != null) ...[
                      FlashcardWidget(
                        card: selected,
                        profile: profile,
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Deck (${cards.length} cards)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final c = cards[index];
                      final isSel = index == _selectedIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedIndex = index;
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.accentCyan
                                      : AppColors.borderNeutral,
                                  width: isSel ? 2 : 1,
                                ),
                                color: AppColors.surfaceGlass,
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.lemma,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textBody,
                                          ),
                                        ),
                                        Text(
                                          c.translation,
                                          style: const TextStyle(
                                            color: AppColors.textSubtext,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'S=${c.stability.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: AppColors.textSubtext,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: cards.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );

        final leading = profile == null
            ? null
            : _DeckRail(
                profile: profile,
                cardCount: cards.length,
                dueCount: data.dueCount,
                onStudyTap: () => _openStudySession(context, profile),
                onDecoderTap: wide
                    ? () => _openSentenceDecoder(context, profile)
                    : null,
              );

        final trailing = (profile != null && selected != null)
            ? _InspectorPanel(card: selected)
            : null;

        return SafeArea(
          child: NexusResponsiveShell(
            maxWidth: constraints.maxWidth,
            leading: leading,
            body: mainScroll,
            trailing: trailing,
          ),
        );
      },
    );
  }
}

class _DeckRail extends StatelessWidget {
  const _DeckRail({
    required this.profile,
    required this.cardCount,
    required this.dueCount,
    required this.onStudyTap,
    this.onDecoderTap,
  });

  final LanguageProfile profile;
  final int cardCount;
  final int dueCount;
  final VoidCallback onStudyTap;

  /// Wide shell only (PRD §8.4); `null` hides the control on narrow layouts.
  final VoidCallback? onDecoderTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'DECKS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSubtext,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accentCyan),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.language,
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$cardCount cards',
                  style: const TextStyle(
                    color: AppColors.textSubtext,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Due now',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSubtext,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dueCount',
            style: const TextStyle(
              color: AppColors.accentMagenta,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStudyTap,
              icon: const Icon(Icons.school_outlined, size: 20),
              label: const Text('Study session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.backgroundPrimary,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          if (onDecoderTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDecoderTap,
                icon: const Icon(Icons.splitscreen_outlined, size: 20),
                label: const Text('Sentence decoder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.accentCyan),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({required this.card});

  final WordCard card;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(card.metadata);
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'INSPECTOR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSubtext,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            pretty,
            style: const TextStyle(
              color: AppColors.textBody,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _BootstrapData {
  _BootstrapData({
    required this.message,
    required this.profile,
    required this.cards,
    required this.dueCount,
  });

  final String message;
  final LanguageProfile? profile;
  final List<WordCard> cards;
  final int dueCount;
}

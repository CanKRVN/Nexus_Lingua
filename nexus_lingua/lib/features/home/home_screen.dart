import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../../core/settings/nexus_settings.dart';
import '../deck_manager/deck_manager_screen.dart';
import '../study/study_session_screen.dart';
import '../../shared/layout/nexus_breakpoints.dart';
import '../../shared/layout/nexus_compact_nav_bar.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/layout/nexus_responsive_shell.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_neon.dart';
import '../../shared/theme/nexus_motion.dart';
import '../../shared/theme/nexus_surfaces.dart';
import '../../shared/widgets/nexus_glow_filled_button.dart';
import '../../shared/widgets/study_mastery_card.dart';

/// Primary shell: deck picker, study entry, global drawer, mastery preview.
class HomeScreen extends StatefulWidget {
  /// Creates the home shell.
  const HomeScreen({super.key, required this.repository});

  final CardRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<_HomeData> _future;
  int _selectedCardIndex = 0;
  LanguageProfile? _activeProfile;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final message = await widget.repository.bootstrapPersistence();
    final profiles = await widget.repository.loadAllProfiles();
    LanguageProfile? profile = _activeProfile;
    final activeId = profile?.id;
    final stillValid =
        activeId != null && profiles.any((p) => p.id == activeId);
    if (!stillValid) {
      profile = profiles.isNotEmpty ? profiles.first : null;
    }
    _activeProfile = profile;
    final cards = profile?.id != null
        ? await widget.repository.loadCardsForProfile(profile!.id!)
        : <WordCard>[];
    var dueCount = 0;
    final pid = profile?.id;
    if (pid != null) {
      dueCount = (await widget.repository.loadDueCardsForProfile(
        pid,
        DateTime.now(),
      ))
          .length;
    }
    return _HomeData(
      message: message,
      profiles: profiles,
      activeProfile: profile,
      cards: cards,
      dueCount: dueCount,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _fastForward7Days(LanguageProfile profile) async {
    final id = profile.id;
    if (id == null) return;
    final n = await widget.repository.debugFastForwardDays(id, 7);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fast-forward 7d: adjusted $n card(s). Due count updated.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setProfile(LanguageProfile? p) {
    setState(() => _activeProfile = p);
    _refresh();
  }

  WordCard? _selectedCard(List<WordCard> cards) {
    if (cards.isEmpty) return null;
    final i = _selectedCardIndex.clamp(0, cards.length - 1);
    return cards[i];
  }

  void _openStudy(BuildContext context, LanguageProfile profile) {
    final s = context.nexusSettings;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StudySessionScreen(
          profile: profile,
          repository: widget.repository,
          sMax: s.sMax,
          effectsEnabled: s.effectsEnabled,
          ratingDisplayStyle: s.ratingStyle,
          studyDirection: s.studyDirection,
        ),
      ),
    );
  }

  void _showDebugInspector(
    BuildContext context,
    WordCard card,
    LanguageProfile profile,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.32,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderNeutral,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'DEBUG · Inspector',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.accentCyan,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),
                Expanded(
                  child: _InspectorPanel(
                    card: card,
                    profile: profile,
                    scrollController: scrollController,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget? _debugInspectorButton(
    BuildContext context,
    LanguageProfile? profile,
    WordCard? selected,
  ) {
    if (!kDebugMode || profile == null || selected == null) {
      return null;
    }
    return IconButton(
      tooltip: 'Debug: inspector & raw JSON',
      icon: Icon(
        Icons.bug_report_outlined,
        color: AppColors.accentCyan.withValues(alpha: 0.85),
      ),
      onPressed: () => _showDebugInspector(context, selected, profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nexus Lingua')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.feedbackMiss,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load your data.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      snapshot.error.toString(),
                      style: const TextStyle(
                        color: AppColors.textSubtext,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    NexusGlowFilledButtonIcon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final profile = data.activeProfile;
        final cards = data.cards;
        final selected = _selectedCard(cards);
        final canStudy = profile?.id != null;
        final debugInspectorAction =
            _debugInspectorButton(context, profile, selected);
        final showCompactNav =
            NexusBreakpoints.layoutClassForWidth(MediaQuery.sizeOf(context).width) ==
                NexusLayoutClass.compact;

        return NexusPageScaffold(
          scaffoldKey: _scaffoldKey,
          navigatorContext: context,
          repository: widget.repository,
          activeProfile: profile,
          onAfterReturnFromPushedRoute: _refresh,
          bottomNavigationBar: showCompactNav
              ? NexusCompactNavBar(
                  repository: widget.repository,
                  activeProfile: profile,
                  onAfterNavigate: _refresh,
                )
              : null,
          title: const Text('Nexus Lingua'),
          actions: [
            if (canStudy)
              ListenableBuilder(
                listenable: context.nexusSettings,
                builder: (context, _) {
                  final primary = Theme.of(context).colorScheme.primary;
                  return TextButton.icon(
                    onPressed: () => _openStudy(context, profile!),
                    style: TextButton.styleFrom(foregroundColor: primary),
                    icon: const Icon(Icons.school_outlined, size: 20),
                    label: Text('Study (${data.dueCount})'),
                  );
                },
              ),
            if (canStudy)
              TextButton(
                onPressed: () => unawaited(_fastForward7Days(profile!)),
                child: Text(
                  'Fast Forward 7 Days',
                  style: TextStyle(
                    color: AppColors.accentMagenta.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ?debugInspectorAction,
          ],
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (data.profiles.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 56,
                          color: AppColors.accentCyan,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No language deck yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a profile and cards in Deck manager.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSubtext),
                        ),
                        const SizedBox(height: 24),
                        NexusGlowFilledButtonIcon(
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) => DeckManagerScreen(
                                  repository: widget.repository,
                                ),
                              ),
                            );
                            if (context.mounted) await _refresh();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Open deck manager'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final isWide =
                  NexusBreakpoints.isWideLayout(constraints.maxWidth);
              final hPad = isWide ? 12.0 : 16.0;

              final mainScroll = RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.all(hPad),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text(
                            data.message,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (!isWide)
                            _ProfilePicker(
                              profiles: data.profiles,
                              value: profile,
                              onChanged: _setProfile,
                            )
                          else if (profile != null) ...[
                            const NexusSectionHeader('Active deck'),
                            const SizedBox(height: 6),
                            Text(
                              profile.displayDeckTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.textSubtext,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (!isWide &&
                              profile != null &&
                              selected != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: StudyMasteryCard(card: selected),
                            ),
                          NexusSectionHeader(
                            'Deck (${cards.length} cards)',
                            magentaAccent: true,
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final c = cards[index];
                            final isSel = index == _selectedCardIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.transparent,
                                child: ListenableBuilder(
                                  listenable: context.nexusSettings,
                                  builder: (context, _) {
                                    final fx =
                                        context.nexusSettings.effectsEnabled;
                                    return InkWell(
                                      onTap: () => setState(() {
                                        _selectedCardIndex = index;
                                      }),
                                      borderRadius: BorderRadius.circular(16),
                                      child: AnimatedContainer(
                                        duration: NexusMotion.interaction,
                                        curve: NexusMotion.interactionCurve,
                                        decoration: nexusPanelDecoration(
                                          context,
                                          highlighted: isSel,
                                        ).copyWith(
                                          boxShadow: isSel &&
                                                  fx &&
                                                  !NexusMotion.preferStaticMotion(
                                                    context,
                                                  )
                                              ? NexusNeon.shadows(
                                                  context,
                                                  NexusNeonTier.active,
                                                )
                                              : null,
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
                                                    c.targetSurface,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textBody,
                                                    ),
                                                  ),
                                                  Text(
                                                    c.translation,
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSubtext,
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
                                    );
                                  },
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

              return SafeArea(
                child: NexusResponsiveShell(
                  maxWidth: constraints.maxWidth,
                  leadingWidth: 208,
                  trailingWidth: 300,
                  leading: isWide
                      ? _HomeDeckRail(
                          profiles: data.profiles,
                          active: profile,
                          onSelect: _setProfile,
                          onOpenDeckManager: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (context) => DeckManagerScreen(
                                  repository: widget.repository,
                                ),
                              ),
                            );
                            if (context.mounted) await _refresh();
                          },
                        )
                      : null,
                  trailing: isWide
                      ? _HomeInspectorRail(
                          profile: profile,
                          card: selected,
                          dueCount: data.dueCount,
                        )
                      : null,
                  body: mainScroll,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeDeckRail extends StatelessWidget {
  const _HomeDeckRail({
    required this.profiles,
    required this.active,
    required this.onSelect,
    required this.onOpenDeckManager,
  });

  final List<LanguageProfile> profiles;
  final LanguageProfile? active;
  final ValueChanged<LanguageProfile?> onSelect;
  final VoidCallback onOpenDeckManager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8),
      child: NexusGlass(
        borderRadius: 14,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NexusSectionHeader('Decks'),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final p in profiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelect(p),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: NexusMotion.interaction,
                            curve: NexusMotion.interactionCurve,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: nexusPanelDecoration(
                              context,
                              highlighted: p.id != null && p.id == active?.id,
                            ),
                            child: Text(
                              p.displayDeckTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontWeight: p.id != null && p.id == active?.id
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onOpenDeckManager,
              icon: Icon(Icons.tune, size: 18, color: scheme.primary),
              label: Text(
                'Deck manager',
                style: TextStyle(color: scheme.primary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeInspectorRail extends StatelessWidget {
  const _HomeInspectorRail({
    required this.profile,
    required this.card,
    required this.dueCount,
  });

  final LanguageProfile? profile;
  final WordCard? card;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8),
      child: NexusGlass(
        borderRadius: 14,
        padding: const EdgeInsets.all(12),
        child: profile == null
            ? Center(
                child: Text(
                  'No deck',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NexusSectionHeader('Inspector'),
                    const SizedBox(height: 8),
                    Text(
                      'Due now · $dueCount',
                      style: context.nexusMono(11, fontWeight: FontWeight.w600)
                          .copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: 14),
                    if (card == null)
                      Text(
                        'Select a card in the deck list for a mastery preview and SRS snapshot.',
                        style: TextStyle(
                          color: AppColors.textSubtext,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      )
                    else ...[
                      StudyMasteryCard(
                        card: card!,
                        animateTranslationReveal: false,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Lemma',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSubtext,
                              letterSpacing: 0.9,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card!.lemma,
                        style: context.nexusMono(13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'SRS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSubtext,
                              letterSpacing: 0.9,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S ${card!.stability.toStringAsFixed(2)}   '
                        'D ${card!.difficulty.toStringAsFixed(2)}   '
                        'R ${card!.retrievability.toStringAsFixed(3)}',
                        style: context.nexusMono(11),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeData {
  _HomeData({
    required this.message,
    required this.profiles,
    required this.activeProfile,
    required this.cards,
    required this.dueCount,
  });

  final String message;
  final List<LanguageProfile> profiles;
  final LanguageProfile? activeProfile;
  final List<WordCard> cards;
  final int dueCount;
}

class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({
    required this.profiles,
    required this.value,
    required this.onChanged,
  });

  final List<LanguageProfile> profiles;
  final LanguageProfile? value;
  final ValueChanged<LanguageProfile?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurface = scheme.onSurface;
    return DropdownButtonFormField<LanguageProfile>(
      // ignore: deprecated_member_use — controlled selection; initialValue is wrong for our reload model
      value: value,
      dropdownColor: scheme.surface,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: onSurface,
            fontWeight: FontWeight.w600,
          ),
      decoration: const InputDecoration(
        labelText: 'Active deck',
        border: OutlineInputBorder(),
      ),
      items: profiles
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(
                p.displayDeckTitle,
                style: TextStyle(color: onSurface),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.card,
    required this.profile,
    this.scrollController,
  });

  final WordCard card;
  final LanguageProfile profile;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.backgroundPrimary,
      child: ListView(
        controller: scrollController,
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
          _kv('Lemma (headword)', card.lemma),
          _kv('Target display', card.targetSurface),
          _kv('Translation', card.translation),
          _kv('S / D / R',
              '${card.stability.toStringAsFixed(2)} / ${card.difficulty.toStringAsFixed(2)} / ${card.retrievability.toStringAsFixed(3)}'),
          _kv('Reviews', '${card.reviewCount}'),
          const SizedBox(height: 8),
          Text(
            'Metadata',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accentCyan,
                ),
          ),
          const SizedBox(height: 6),
          ...({
            for (final k in profile.features) k,
            for (final k in profile.featuresKnown) k,
          }.toList()
                ..sort())
              .map((k) {
            final v = card.metadata[k];
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      k,
                      style: const TextStyle(
                        color: AppColors.textSubtext,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${v ?? '—'}',
                      style: const TextStyle(
                        color: AppColors.textBody,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Raw JSON',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSubtext,
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(card.metadata),
            style: const TextStyle(
              color: AppColors.textBody,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: const TextStyle(
                color: AppColors.textSubtext,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: AppColors.textBody, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

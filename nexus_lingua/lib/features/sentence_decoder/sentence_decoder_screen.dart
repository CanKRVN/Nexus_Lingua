import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../../core/text/sentence_tokenizer.dart';
import '../../shared/layout/nexus_breakpoints.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/widgets/nexus_glow_filled_button.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_surfaces.dart';

/// Split view: paste text → token list; tap token to add card (PRD §8.4).
///
/// Wide: [Row] panes; narrow: stacked [Column]. Uses [CardRepository] only.
class SentenceDecoderScreen extends StatefulWidget {
  /// Creates the decoder for [profile] (must have [LanguageProfile.id]).
  const SentenceDecoderScreen({
    super.key,
    required this.profile,
    required this.repository,
  });

  final LanguageProfile profile;
  final CardRepository repository;

  @override
  State<SentenceDecoderScreen> createState() => _SentenceDecoderScreenState();
}

class _SentenceDecoderScreenState extends State<SentenceDecoderScreen> {
  late final TextEditingController _textController;
  Set<String> _lemmaLower = {};

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));
    _reloadLemmas();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _reloadLemmas() async {
    final id = widget.profile.id;
    if (id == null) return;
    final s = await widget.repository.loadLemmaSetForProfile(id);
    if (!mounted) return;
    setState(() {
      _lemmaLower = s.map((e) => e.toLowerCase()).toSet();
    });
  }

  bool _isKnownLemma(String token) =>
      _lemmaLower.contains(token.toLowerCase());

  Map<String, dynamic> _defaultMetadata() {
    final m = <String, dynamic>{};
    for (final f in {
      ...widget.profile.features,
      ...widget.profile.featuresKnown,
    }) {
      if (f == 'case_sensitive') {
        m[f] = false;
      } else {
        m[f] = null;
      }
    }
    return m;
  }

  Future<void> _onTokenTap(String lemma) async {
    final translation = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New card',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                lemma,
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textBody),
                decoration: const InputDecoration(
                  labelText: 'Translation',
                  labelStyle: TextStyle(color: AppColors.textSubtext),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentCyan),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentCyan, width: 2),
                  ),
                ),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isEmpty) return;
                  Navigator.of(ctx).pop(t);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  NexusGlowFilledButton(
                    onPressed: () {
                      final t = ctrl.text.trim();
                      if (t.isEmpty) return;
                      Navigator.of(ctx).pop(t);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || translation == null || translation.isEmpty) return;

    final pid = widget.profile.id;
    if (pid == null) return;

    final now = DateTime.now();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;
    final due = DateTime.fromMillisecondsSinceEpoch(nowSec * 1000, isUtc: true)
        .toLocal();

    try {
      await widget.repository.insertCard(
        WordCard(
          profileId: pid,
          lemma: lemma,
          translation: translation,
          dueDate: due,
          createdAt: now,
          metadata: _defaultMetadata(),
        ),
      );
      if (!mounted) return;
      await _reloadLemmas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $lemma'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.feedbackMiss,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SentenceTokenizer.tokenize(_textController.text);
    final wide = NexusBreakpoints.isWideLayout(
      MediaQuery.sizeOf(context).width,
    );

    final inputPane = DecoratedBox(
      decoration: nexusPanelDecoration(context, borderRadius: 14),
      child: TextField(
        controller: _textController,
        maxLines: wide ? null : 8,
        minLines: wide ? null : 4,
        expands: wide,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(color: AppColors.textBody),
        decoration: const InputDecoration(
          hintText: 'Paste source-language text…',
          hintStyle: TextStyle(color: AppColors.textSubtext),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );

    final tokenPane = DecoratedBox(
      decoration: nexusPanelDecoration(context, borderRadius: 14),
      child: tokens.isEmpty
          ? const Center(
              child: Text(
                'Tokens appear here',
                style: TextStyle(color: AppColors.textSubtext),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tokens)
                    _TokenChip(
                      text: t,
                      known: _isKnownLemma(t),
                      onTap: () => _onTokenTap(t),
                    ),
                ],
              ),
            ),
    );

    return NexusPageScaffold(
      navigatorContext: context,
      repository: widget.repository,
      activeProfile: widget.profile,
      title: const Text('Sentence decoder'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 1, child: inputPane),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: tokenPane),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 200, child: inputPane),
                    const SizedBox(height: 16),
                    Expanded(child: tokenPane),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.text,
    required this.known,
    required this.onTap,
  });

  final String text;
  final bool known;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: known ? AppColors.accentCyan : AppColors.borderNeutral,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textBody,
              decoration: known ? TextDecoration.underline : null,
              decorationColor: AppColors.accentCyan,
              decorationThickness: 2,
            ),
          ),
        ),
      ),
    );
  }
}

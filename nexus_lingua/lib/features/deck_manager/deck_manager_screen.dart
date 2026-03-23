import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/catalog/language_feature_catalog.dart';
import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../../core/models/word_card.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_surfaces.dart';
import '../../shared/widgets/nexus_glow_filled_button.dart';

/// PRD §8.1–8.2 — profiles, card CRUD, JSON import (paste).
class DeckManagerScreen extends StatefulWidget {
  /// Creates the deck manager.
  const DeckManagerScreen({
    super.key,
    required this.repository,
    this.initialProfileId,
  });

  final CardRepository repository;

  /// Optional profile to pre-select.
  final int? initialProfileId;

  @override
  State<DeckManagerScreen> createState() => _DeckManagerScreenState();
}

class _DeckManagerScreenState extends State<DeckManagerScreen> {
  static const String _englishTurkishA1ExampleJson = '''
{
  "deck": { "language": "English", "known_language": "Turkish" },
  "cards": [
    { "lemma": "hello", "translation": "merhaba" },
    { "lemma": "goodbye", "translation": "hosca kal" },
    { "lemma": "please", "translation": "lutfen" },
    { "lemma": "thanks", "translation": "tesekkurler" },
    { "lemma": "yes", "translation": "evet" },
    { "lemma": "no", "translation": "hayir" },
    { "lemma": "water", "translation": "su" },
    { "lemma": "bread", "translation": "ekmek" },
    { "lemma": "milk", "translation": "sut" },
    { "lemma": "apple", "translation": "elma" },
    { "lemma": "house", "translation": "ev" },
    { "lemma": "school", "translation": "okul" },
    { "lemma": "book", "translation": "kitap" },
    { "lemma": "pen", "translation": "kalem" },
    { "lemma": "table", "translation": "masa" },
    { "lemma": "chair", "translation": "sandalye" },
    { "lemma": "door", "translation": "kapi" },
    { "lemma": "window", "translation": "pencere" },
    { "lemma": "mother", "translation": "anne" },
    { "lemma": "father", "translation": "baba" },
    { "lemma": "brother", "translation": "erkek kardes" },
    { "lemma": "sister", "translation": "kiz kardes" },
    { "lemma": "friend", "translation": "arkadas" },
    { "lemma": "name", "translation": "isim" },
    { "lemma": "day", "translation": "gun" },
    { "lemma": "night", "translation": "gece" },
    { "lemma": "today", "translation": "bugun" },
    { "lemma": "tomorrow", "translation": "yarin" },
    { "lemma": "go", "translation": "gitmek" },
    { "lemma": "come", "translation": "gelmek" }
  ]
}
''';

  late Future<void> _reload;
  List<LanguageProfile> _profiles = [];
  LanguageProfile? _selected;
  List<WordCard> _cards = [];

  @override
  void initState() {
    super.initState();
    _reload = _load();
  }

  Future<void> _load() async {
    final list = await widget.repository.loadAllProfiles();
    if (!mounted) return;
    setState(() {
      _profiles = list;
      if (_selected == null ||
          !_profiles.any((p) => p.id == _selected!.id)) {
        _selected = _pickProfile(list, widget.initialProfileId);
      }
    });
    await _loadCards();
  }

  LanguageProfile? _pickProfile(List<LanguageProfile> list, int? wantId) {
    if (list.isEmpty) return null;
    if (wantId != null) {
      for (final p in list) {
        if (p.id == wantId) return p;
      }
    }
    return list.first;
  }

  Future<void> _loadCards() async {
    final p = _selected;
    if (p == null || p.id == null) {
      setState(() => _cards = []);
      return;
    }
    final c = await widget.repository.loadCardsForProfile(p.id!);
    if (!mounted) return;
    setState(() => _cards = c);
  }

  Future<void> _refresh() async {
    final fut = _load();
    setState(() {
      _reload = fut;
    });
    await fut;
  }

  Map<String, dynamic> _emptyMetadata(LanguageProfile p) {
    final m = <String, dynamic>{};
    final keys = {...p.features, ...p.featuresKnown};
    for (final k in keys) {
      if (k == 'case_sensitive') {
        m[k] = false;
      } else {
        m[k] = null;
      }
    }
    return m;
  }

  List<String> _orderedMetaKeys(LanguageProfile p) {
    final set = {...p.features, ...p.featuresKnown};
    final ordered = LanguageFeatureCatalog.allKeys.where(set.contains).toList();
    final extra = set.difference(LanguageFeatureCatalog.allKeys.toSet()).toList()
      ..sort();
    return [...ordered, ...extra];
  }

  @override
  Widget build(BuildContext context) {
    return NexusPageScaffold(
      navigatorContext: context,
      repository: widget.repository,
      activeProfile: _selected,
      title: const Text('Deck manager'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: FutureBuilder<void>(
        future: _reload,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Language profiles',
                      style: nexusSectionTitleStyle(context),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _showProfileEditor(context, null),
                    child: const Text('New profile'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_profiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No profiles yet. Create one to add cards.',
                    style: TextStyle(color: AppColors.textSubtext),
                  ),
                )
              else
                ..._profiles.map((p) {
                  final sel = _selected?.id == p.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() => _selected = p);
                          _loadCards();
                        },
                        child: DecoratedBox(
                          decoration: nexusPanelDecoration(context, highlighted: sel),
                          child: ListTile(
                            selected: sel,
                            selectedTileColor: Colors.transparent,
                            title: Text(
                              p.displayDeckTitle,
                              style: const TextStyle(color: AppColors.textBody),
                            ),
                            subtitle: Text(
                              '${p.features.length} target · ${p.featuresKnown.length} known · id ${p.id}',
                              style: const TextStyle(
                                color: AppColors.textSubtext,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.accentCyan),
                                  onPressed: () =>
                                      _showProfileEditor(context, p),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.feedbackMiss),
                                  onPressed: () =>
                                      _confirmDeleteProfile(context, p),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const Divider(color: AppColors.borderNeutral, height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cards — ${_selected?.displayDeckTitle ?? "select profile"}',
                      style: nexusSectionTitleStyle(
                        context,
                        color: AppColors.accentMagenta,
                      ),
                    ),
                  ),
                  if (_selected?.id != null)
                    FilledButton.tonal(
                      onPressed: () => _showCardEditor(context, null),
                      child: const Text('New card'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import Deck (JSON/CSV/TSV)'),
              ),
              const SizedBox(height: 12),
              if (_selected?.id == null)
                const Text(
                  'Select a profile to list cards.',
                  style: TextStyle(color: AppColors.textSubtext),
                )
              else if (_cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No cards in this deck.',
                    style: TextStyle(color: AppColors.textSubtext),
                  ),
                )
              else
                ..._cards.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: nexusPanelDecoration(context),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          title: Text(
                            c.targetSurface,
                            style: const TextStyle(
                              color: AppColors.textBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            c.translation,
                            style:
                                const TextStyle(color: AppColors.textSubtext),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppColors.accentCyan),
                                onPressed: () => _showCardEditor(context, c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.feedbackMiss),
                                onPressed: () => _confirmDeleteCard(context, c),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteProfile(
    BuildContext context,
    LanguageProfile p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Deletes "${p.language}" and all its cards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          NexusGlowFilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.feedbackMiss,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && p.id != null) {
      await widget.repository.deleteProfile(p.id!);
      setState(() {
        _selected = null;
      });
      await _refresh();
    }
  }

  Future<void> _confirmDeleteCard(BuildContext context, WordCard c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Remove "${c.targetSurface}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          NexusGlowFilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.feedbackMiss,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && c.id != null) {
      await widget.repository.deleteCard(c.id!);
      await _refresh();
    }
  }

  Future<void> _showProfileEditor(
    BuildContext context,
    LanguageProfile? existing,
  ) async {
    final targetLangCtrl =
        TextEditingController(text: existing?.language ?? '');
    final knownLangCtrl =
        TextEditingController(text: existing?.knownLanguage ?? '');
    final chosenTarget = <String>{...?existing?.features};
    final chosenKnown = <String>{...?existing?.featuresKnown};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'New profile' : 'Edit profile',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetLangCtrl,
                      style: const TextStyle(color: AppColors.textBody),
                      decoration: const InputDecoration(
                        labelText: 'Target language (learning)',
                        helperText: 'e.g. German',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: knownLangCtrl,
                      style: const TextStyle(color: AppColors.textBody),
                      decoration: const InputDecoration(
                        labelText: 'Known language (native / L1)',
                        helperText: 'e.g. English — optional',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target language — metadata on cards',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentCyan,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...LanguageFeatureCatalog.allKeys.map((key) {
                      return CheckboxListTile(
                        title: Text(LanguageFeatureCatalog.labelFor(key)),
                        value: chosenTarget.contains(key),
                        activeColor: AppColors.accentCyan,
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              chosenTarget.add(key);
                            } else {
                              chosenTarget.remove(key);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    Text(
                      'Known language — metadata on cards',
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: AppColors.accentMagenta,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...LanguageFeatureCatalog.allKeys.map((key) {
                      return CheckboxListTile(
                        title: Text(LanguageFeatureCatalog.labelFor(key)),
                        value: chosenKnown.contains(key),
                        activeColor: AppColors.accentMagenta,
                        onChanged: (v) {
                          setModal(() {
                            if (v == true) {
                              chosenKnown.add(key);
                            } else {
                              chosenKnown.remove(key);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    NexusGlowFilledButton(
                      onPressed: () async {
                        final target = targetLangCtrl.text.trim();
                        if (target.isEmpty) return;
                        final known = knownLangCtrl.text.trim();
                        final featsT = chosenTarget.toList()..sort();
                        final featsK = chosenKnown.toList()..sort();
                        final now = DateTime.now();
                        try {
                          if (existing?.id == null) {
                            await widget.repository.insertProfile(
                              LanguageProfile(
                                language: target,
                                knownLanguage: known,
                                features: featsT,
                                featuresKnown: featsK,
                                createdAt: now,
                              ),
                            );
                          } else {
                            await widget.repository.updateProfile(
                              LanguageProfile(
                                id: existing!.id,
                                language: target,
                                knownLanguage: known,
                                features: featsT,
                                featuresKnown: featsK,
                                createdAt: existing.createdAt,
                              ),
                            );
                          }
                          if (context.mounted) Navigator.pop(ctx);
                          await _refresh();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showCardEditor(
    BuildContext context,
    WordCard? existing,
  ) async {
    final sel = _selected;
    if (sel == null || sel.id == null) return;

    final lemmaCtrl = TextEditingController(text: existing?.lemma ?? '');
    final transCtrl =
        TextEditingController(text: existing?.translation ?? '');
    final meta =
        Map<String, dynamic>.from(existing?.metadata ?? _emptyMetadata(sel));
    final metaKeyList = _orderedMetaKeys(sel);
    final metaCtrls = <String, TextEditingController>{};
    for (final key in metaKeyList) {
      if (key == 'case_sensitive') continue;
      metaCtrls[key] = TextEditingController(
        text: meta[key]?.toString() ?? '',
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundPrimary,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'New card' : 'Edit card',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lemmaCtrl,
                      style: const TextStyle(color: AppColors.textBody),
                      decoration: const InputDecoration(
                        labelText: 'Lemma (target)',
                        helperText: 'Headword only, e.g. Buch — not der/die/das',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: transCtrl,
                      style: const TextStyle(color: AppColors.textBody),
                      decoration: const InputDecoration(
                        labelText: 'Translation (known language gloss)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...metaKeyList.map((key) {
                      if (key == 'case_sensitive') {
                        return SwitchListTile(
                          title: Text(LanguageFeatureCatalog.labelFor(key)),
                          value: meta[key] == true,
                          activeThumbColor: AppColors.accentCyan,
                          onChanged: (v) =>
                              setModal(() => meta[key] = v),
                        );
                      }
                      final tc = metaCtrls[key];
                      if (tc == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: tc,
                          style: const TextStyle(color: AppColors.textBody),
                          decoration: InputDecoration(
                            labelText: LanguageFeatureCatalog.labelFor(key),
                          ),
                          onChanged: (v) =>
                              setModal(() => meta[key] = v.isEmpty ? null : v),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    NexusGlowFilledButton(
                      onPressed: () async {
                        for (final e in metaCtrls.entries) {
                          final t = e.value.text.trim();
                          meta[e.key] = t.isEmpty ? null : t;
                        }
                        final lemma = lemmaCtrl.text.trim();
                        final tr = transCtrl.text.trim();
                        if (lemma.isEmpty || tr.isEmpty) return;
                        final now = DateTime.now();
                        try {
                          if (existing?.id == null) {
                            await widget.repository.insertCard(
                              WordCard(
                                profileId: sel.id!,
                                lemma: lemma,
                                translation: tr,
                                dueDate: now,
                                createdAt: now,
                                metadata: meta,
                              ),
                            );
                          } else {
                            await widget.repository.updateCard(
                              WordCard(
                                id: existing!.id,
                                profileId: sel.id!,
                                lemma: lemma,
                                translation: tr,
                                stability: existing.stability,
                                difficulty: existing.difficulty,
                                retrievability: existing.retrievability,
                                dueDate: existing.dueDate,
                                reviewCount: existing.reviewCount,
                                metadata: meta,
                                createdAt: existing.createdAt,
                                lastReviewedAt: existing.lastReviewedAt,
                              ),
                            );
                          }
                          if (context.mounted) Navigator.pop(ctx);
                          await _refresh();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save card'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      lemmaCtrl.dispose();
      transCtrl.dispose();
      for (final c in metaCtrls.values) {
        c.dispose();
      }
    });
  }

  Future<void> _showImportDialog() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import deck data'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accepted input:\n'
                '- Backup JSON (language_profiles + word_cards)\n'
                '- Deck JSON list / {"cards":[...]} with lemma + translation\n'
                '- Excel/Sheets paste (TSV) or CSV with header',
                style: TextStyle(color: AppColors.textSubtext, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 10,
                style: const TextStyle(
                  color: AppColors.textBody,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  hintText: 'Paste JSON / TSV / CSV here',
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await _pickFileAndPreview(ctx);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('File pick failed: $e')),
                );
              }
            },
            icon: const Icon(Icons.attach_file),
            label: const Text('Pick file'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              await _importFromMixedInput(_englishTurkishA1ExampleJson);
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Example file'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          NexusGlowFilledButton(
            onPressed: () async {
              try {
                final text = ctrl.text.trim();
                if (text.isEmpty) {
                  throw ArgumentError('Paste JSON / TSV / CSV content first.');
                }
                final nav = Navigator.of(ctx);
                nav.pop();
                await _importFromMixedInput(text);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Import failed: $e')),
                );
              }
            },
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFileAndPreview(BuildContext dialogContext) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'csv', 'tsv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final name = picked.name.toLowerCase();
    final bytes = picked.bytes;
    if (bytes == null) {
      throw StateError(
        'Selected file bytes are unavailable. Please re-pick the file.',
      );
    }

    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
    if (name.endsWith('.xlsx')) {
      final rows = _parseXlsxRows(bytes);
      await _previewAndConfirmRows(rows);
      return;
    }

    final raw = utf8.decode(bytes);
    await _importFromMixedInput(raw);
  }

  Future<void> _importFromMixedInput(String text) async {
    final asJson = _tryDecodeJson(text);
    if (asJson is Map<String, dynamic> &&
        asJson.containsKey('language_profiles') &&
        asJson.containsKey('word_cards')) {
      final r = await widget.repository.importBackupProfilesAndCards(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.preferences > 0
                ? 'Imported ${r.profiles} profiles, ${r.cards} cards, '
                    '${r.preferences} app preferences'
                : 'Imported ${r.profiles} profiles, ${r.cards} cards',
          ),
        ),
      );
      await _refresh();
      return;
    }

    final rows = _parseDeckRows(text, asJson: asJson);
    await _previewAndConfirmRows(rows);
  }

  Future<void> _previewAndConfirmRows(List<Map<String, dynamic>> rows) async {
    final normalized = rows.map(_normalizeDeckRow).toList();
    final valid = normalized.where((row) {
      final lemma = (row['lemma'] ?? '').toString().trim();
      final translation = (row['translation'] ?? '').toString().trim();
      return lemma.isNotEmpty && translation.isNotEmpty;
    }).toList();

    if (valid.isEmpty) {
      throw StateError(
        'No valid rows found. Need at least lemma + translation columns.',
      );
    }
    final previewRows = valid.take(20).toList();
    final columns = _previewColumnsFromRows(previewRows);

    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preview import (${valid.length} rows)'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  for (final c in columns) DataColumn(label: Text(c)),
                ],
                rows: [
                  for (final row in previewRows)
                    DataRow(
                      cells: [
                        for (final c in columns)
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: Text(
                                '${row[c] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          NexusGlowFilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Import ${valid.length} rows'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    final sel = _selected;
    if (sel == null || sel.id == null) {
      throw StateError('Select a profile before importing deck rows.');
    }
    final now = DateTime.now();
    var inserted = 0;
    for (final row in rows) {
      final lemma = (row['lemma'] ?? '').toString().trim();
      final translation = (row['translation'] ?? '').toString().trim();
      if (lemma.isEmpty || translation.isEmpty) continue;

      final metadata = <String, dynamic>{};
      for (final entry in row.entries) {
        final k = entry.key;
        if (k == 'lemma' || k == 'translation') continue;
        final v = entry.value;
        if (v == null) continue;
        if (v is String && v.trim().isEmpty) continue;
        metadata[k] = v;
      }

      await widget.repository.insertCard(
        WordCard(
          profileId: sel.id!,
          lemma: lemma,
          translation: translation,
          dueDate: now,
          createdAt: now,
          metadata: metadata,
        ),
      );
      inserted++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported 0 profiles, $inserted cards')),
    );
    await _refresh();
  }

  Object? _tryDecodeJson(String text) {
    final t = text.trimLeft();
    if (!(t.startsWith('{') || t.startsWith('['))) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _parseDeckRows(String text, {Object? asJson}) {
    if (asJson != null) {
      if (asJson is List) {
        return asJson
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry('$k', v)))
            .map(_normalizeDeckRow)
            .toList();
      }
      if (asJson is Map<String, dynamic>) {
        final cards = asJson['cards'];
        if (cards is List) {
          return cards
              .whereType<Map>()
              .map((m) => m.map((k, v) => MapEntry('$k', v)))
              .map(_normalizeDeckRow)
              .toList();
        }
      }
      throw FormatException('JSON import expects a list or {"cards":[...]}');
    }

    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trimRight())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) {
      throw FormatException('Tabular import needs a header + at least one row.');
    }

    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    final table = delimiter == '\t'
        ? Csv(
            fieldDelimiter: '\t',
            autoDetect: false,
            dynamicTyping: false,
          ).decode(lines.join('\n'))
        : Csv(
            autoDetect: false,
            dynamicTyping: false,
          ).decode(lines.join('\n'));
    if (table.length < 2) {
      throw FormatException('Tabular import needs a header + at least one row.');
    }
    final header = table.first.map((h) => '$h'.trim().toLowerCase()).toList();
    final lemmaIdx = header.indexWhere((h) => h == 'lemma' || h == 'target');
    final transIdx = header.indexWhere(
      (h) => h == 'translation' || h == 'gloss' || h == 'known',
    );
    if (lemmaIdx < 0 || transIdx < 0) {
      throw FormatException(
        'Header must include lemma + translation (or target + gloss).',
      );
    }

    final out = <Map<String, dynamic>>[];
    for (final cols in table.skip(1)) {
      final row = <String, dynamic>{};
      for (var i = 0; i < header.length && i < cols.length; i++) {
        final key = header[i];
        final value = '${cols[i]}'.trim();
        if (key.isEmpty || value.isEmpty) continue;
        row[key] = value;
      }
      out.add(_normalizeDeckRow(row));
    }
    return out;
  }

  List<Map<String, dynamic>> _parseXlsxRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final tableName =
        excel.tables.keys.isNotEmpty ? excel.tables.keys.first : null;
    if (tableName == null) {
      throw FormatException('XLSX has no worksheet.');
    }
    final table = excel.tables[tableName];
    if (table == null || table.rows.length < 2) {
      throw FormatException('XLSX needs header + at least one row.');
    }
    final header = table.rows.first
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();
    final lemmaIdx = header.indexWhere((h) => h == 'lemma' || h == 'target');
    final transIdx = header.indexWhere(
      (h) => h == 'translation' || h == 'gloss' || h == 'known',
    );
    if (lemmaIdx < 0 || transIdx < 0) {
      throw FormatException(
        'XLSX header must include lemma + translation (or target + gloss).',
      );
    }

    final out = <Map<String, dynamic>>[];
    for (final cols in table.rows.skip(1)) {
      final row = <String, dynamic>{};
      for (var i = 0; i < header.length && i < cols.length; i++) {
        final key = header[i];
        final value = (cols[i]?.value?.toString() ?? '').trim();
        if (key.isEmpty || value.isEmpty) continue;
        row[key] = value;
      }
      out.add(_normalizeDeckRow(row));
    }
    return out;
  }

  List<String> _previewColumnsFromRows(List<Map<String, dynamic>> rows) {
    final extras = <String>{};
    for (final row in rows) {
      for (final k in row.keys) {
        if (k != 'lemma' && k != 'translation') {
          extras.add(k);
        }
      }
    }
    final extraSorted = extras.toList()..sort();
    return ['lemma', 'translation', ...extraSorted.take(4)];
  }

  Map<String, dynamic> _normalizeDeckRow(Map<String, dynamic> row) {
    final out = <String, dynamic>{};
    for (final e in row.entries) {
      final k = e.key.trim().toLowerCase();
      if (k == 'target') {
        out['lemma'] = e.value;
      } else if (k == 'gloss' || k == 'known') {
        out['translation'] = e.value;
      } else {
        out[k] = e.value;
      }
    }
    return out;
  }
}

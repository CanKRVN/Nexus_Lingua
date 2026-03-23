import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/study_direction.dart';
import '../../core/platform/backup_export.dart';
import '../../core/settings/nexus_settings.dart';
import '../../core/theme/theme_provider.dart';
import '../../shared/layout/nexus_page_scaffold.dart';
import '../../shared/widgets/nexus_glow_filled_button.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/nexus_surfaces.dart';
import '../../shared/widgets/fsrs_rating_row.dart';

/// PRD §8.5 — rating style, S_max, effects, backup.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings UI.
  const SettingsScreen({super.key, required this.repository});

  /// Data access for export.
  final CardRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sMaxController = TextEditingController();

  @override
  void dispose() {
    _sMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.nexusSettings;
    final themeProvider = context.themeProvider;
    _sMaxController.text = settings.sMax.toStringAsFixed(0);

    return NexusPageScaffold(
      navigatorContext: context,
      repository: widget.repository,
      activeProfile: null,
      title: const Text('Settings'),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Study & display',
                style: nexusSectionTitleStyle(context),
              ),
              const SizedBox(height: 12),
              Text(
                'S_max (XP bar scale)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sMaxController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textBody),
                      decoration: const InputDecoration(
                        hintText: '365',
                      ),
                      onSubmitted: (v) {
                        final n = double.tryParse(v);
                        if (n != null) {
                          settings.setSMax(n);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  NexusGlowFilledButton(
                    onPressed: () {
                      final n = double.tryParse(_sMaxController.text);
                      if (n != null) {
                        settings.setSMax(n);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('S_max saved')),
                        );
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Typist direction (wide layout)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Which side you see first; you type the other.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubtext,
                    ),
              ),
              const SizedBox(height: 8),
              ...StudyDirection.values.map((d) {
                return RadioListTile<StudyDirection>(
                  title: Text(d.shortLabel),
                  subtitle: Text(
                    d.description,
                    style: const TextStyle(
                      color: AppColors.textSubtext,
                      fontSize: 12,
                    ),
                  ),
                  value: d,
                  // ignore: deprecated_member_use
                  groupValue: settings.studyDirection,
                  activeColor: AppColors.accentCyan,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) settings.setStudyDirection(v);
                  },
                );
              }),
              const SizedBox(height: 24),
              Text(
                'Compact rating row',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ...RatingDisplayStyle.values.map((s) {
                return RadioListTile<RatingDisplayStyle>(
                  title: Text(_styleLabel(s)),
                  value: s,
                  // ignore: deprecated_member_use
                  groupValue: settings.ratingStyle,
                  activeColor: AppColors.accentCyan,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) settings.setRatingStyle(v);
                  },
                );
              }),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Motion effects'),
                subtitle: const Text('Flip animation, green beam, miss pulse'),
                value: settings.effectsEnabled,
                activeThumbColor: AppColors.accentCyan,
                onChanged: settings.setEffectsEnabled,
              ),
              SwitchListTile(
                title: const Text('Light theme'),
                subtitle: const Text('Use light palette instead of dark'),
                value: themeProvider.themeMode == ThemeMode.light,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (v) => themeProvider.setThemeMode(
                  v ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
              const Divider(color: AppColors.borderNeutral, height: 40),
              Text(
                'Data',
                style: nexusSectionTitleStyle(context),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.download_outlined,
                    color: AppColors.accentCyan),
                title: const Text('Backup to JSON file'),
                subtitle: const Text(
                  'Web: browser download. Desktop: Documents folder.',
                ),
                onTap: () async {
                  try {
                    final json = await widget.repository.exportBackupJson();
                    final name =
                        'nexus_lingua_backup_${DateTime.now().millisecondsSinceEpoch}.json';
                    await exportBackupToFile(name, json);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saved: $name (or clipboard fallback)'),
                          backgroundColor: AppColors.accentGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: $e'),
                          backgroundColor: AppColors.feedbackMiss,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _styleLabel(RatingDisplayStyle s) {
    switch (s) {
      case RatingDisplayStyle.labels:
        return 'Labels (Miss / Hard / …)';
      case RatingDisplayStyle.symbols:
        return 'Symbols (✕ / ↑ / …)';
      case RatingDisplayStyle.colorsOnly:
        return 'Colors only';
    }
  }
}

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../navigation/nexus_navigation.dart';

/// Bottom [NavigationBar] for [NexusLayoutClass.compact] only (UI-R2).
///
/// Launches primary destinations; does not track route stack (each tap runs navigation).
class NexusCompactNavBar extends StatefulWidget {
  /// Creates the compact launch bar.
  const NexusCompactNavBar({
    super.key,
    required this.repository,
    required this.activeProfile,
    required this.onAfterNavigate,
  });

  final CardRepository repository;

  /// When non-null with [LanguageProfile.id], Study is enabled.
  final LanguageProfile? activeProfile;

  /// e.g. reload home data after returning from a pushed screen.
  final Future<void> Function() onAfterNavigate;

  @override
  State<NexusCompactNavBar> createState() => _NexusCompactNavBarState();
}

class _NexusCompactNavBarState extends State<NexusCompactNavBar> {
  int _index = 0;

  Future<void> _go(int i, Future<void> Function() action) async {
    setState(() => _index = i);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _index = 0);
    }
    if (mounted) await widget.onAfterNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = widget.activeProfile;
    final canStudy = profile?.id != null;

    return NavigationBar(
      height: 64,
      selectedIndex: _index,
      backgroundColor: scheme.surface.withValues(alpha: 0.94),
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) {
        if (i == 0 && !canStudy) return;
        switch (i) {
          case 0:
            unawaited(
              _go(
                i,
                () => NexusNavigation.toStudy(
                  context,
                  widget.repository,
                  profile!,
                ),
              ),
            );
            break;
          case 1:
            unawaited(
              _go(
                i,
                () => NexusNavigation.toDeckManager(
                  context,
                  widget.repository,
                  initialProfileId: profile?.id,
                ),
              ),
            );
            break;
          case 2:
            unawaited(
              _go(
                i,
                () => NexusNavigation.toDashboard(context, widget.repository),
              ),
            );
            break;
          case 3:
            unawaited(
              _go(
                i,
                () => NexusNavigation.toSettings(context, widget.repository),
              ),
            );
            break;
          default:
            break;
        }
      },
      destinations: [
        NavigationDestination(
          icon: Icon(
            Icons.school_outlined,
            color: canStudy
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.35),
          ),
          label: 'Study',
        ),
        const NavigationDestination(
          icon: Icon(Icons.layers_outlined),
          label: 'Decks',
        ),
        const NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: 'Stats',
        ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    );
  }
}

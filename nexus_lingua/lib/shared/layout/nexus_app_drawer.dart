import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../navigation/nexus_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/spectral/spectral_hud_tokens.dart';

/// Consistent end drawer: Home, Study, Deck manager, Decoder, Dashboard, Settings.
class NexusAppDrawer extends StatelessWidget {
  /// Creates the app-wide navigation drawer.
  const NexusAppDrawer({
    super.key,
    required this.navigatorContext,
    required this.repository,
    this.activeProfile,
    this.onAfterReturnFromPushedRoute,
  });

  /// Context whose [Navigator] owns the feature route stack (host [Scaffold]).
  final BuildContext navigatorContext;

  final CardRepository repository;

  /// Enables Study + Sentence decoder entries when non-null with [LanguageProfile.id].
  final LanguageProfile? activeProfile;

  /// When the shell was the only route, run after a pushed feature route is popped
  /// (e.g. [HomeScreen] reload).
  final Future<void> Function()? onAfterReturnFromPushedRoute;

  bool get _hasDeck => activeProfile?.id != null;

  Future<void> _go(
    BuildContext drawerContext,
    Future<void> Function(BuildContext nav) navigate,
  ) async {
    final nav = navigatorContext;
    final wasRoot = ModalRoute.of(nav)?.isFirst ?? true;
    Navigator.pop(drawerContext);
    await navigate(nav);
    if (wasRoot) await onAfterReturnFromPushedRoute?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = context.nexusExtras;
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: SpectralHudTokens.blurSigma,
            sigmaY: SpectralHudTokens.blurSigma,
          ),
          child: Container(
            color: Color.alphaBlend(
              scheme.primary.withValues(
                alpha: SpectralHudTokens.overlayOpacity(context),
              ),
              ex.drawerGlassFill,
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
            Text(
              'NEXUS',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.home_outlined, color: scheme.onSurface),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
                NexusNavigation.goHome(navigatorContext);
              },
            ),
            if (_hasDeck)
              ListTile(
                leading: Icon(Icons.school_outlined, color: scheme.primary),
                title: const Text('Study'),
                onTap: () {
                  final p = activeProfile!;
                  unawaited(_go(context, (nav) => NexusNavigation.toStudy(
                        nav,
                        repository,
                        p,
                      )));
                },
              ),
            ListTile(
              leading: Icon(Icons.layers_outlined, color: scheme.primary),
              title: const Text('Deck manager'),
              onTap: () => unawaited(_go(
                    context,
                    (nav) => NexusNavigation.toDeckManager(
                          nav,
                          repository,
                          initialProfileId: activeProfile?.id,
                        ),
                  )),
            ),
            if (_hasDeck)
              ListTile(
                leading: Icon(Icons.splitscreen_outlined, color: scheme.primary),
                title: const Text('Sentence decoder'),
                onTap: () {
                  final p = activeProfile!;
                  unawaited(_go(
                    context,
                    (nav) => NexusNavigation.toSentenceDecoder(
                          nav,
                          repository,
                          p,
                        ),
                  ));
                },
              ),
            ListTile(
              leading:
                  Icon(Icons.insights_outlined, color: ex.secondaryAccent),
              title: const Text('Mastery dashboard'),
              onTap: () => unawaited(_go(
                    context,
                    (nav) => NexusNavigation.toDashboard(nav, repository),
                  )),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: ex.textSubtext),
              title: const Text('Settings'),
              onTap: () => unawaited(_go(
                    context,
                    (nav) => NexusNavigation.toSettings(nav, repository),
                  )),
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

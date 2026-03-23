import 'package:flutter/material.dart';

import '../../core/database/card_repository.dart';
import '../../core/models/language_profile.dart';
import '../../core/settings/nexus_settings.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/deck_manager/deck_manager_screen.dart';
import '../../features/sentence_decoder/sentence_decoder_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/study/study_session_screen.dart';

/// Cross-screen routes for the global app drawer (push vs replace under [Home]).
class NexusNavigation {
  NexusNavigation._();

  static void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static Future<void> _pushOrReplace(
    BuildContext context,
    Route<void> route,
  ) async {
    final nav = Navigator.of(context);
    final atStackRoot = ModalRoute.of(context)?.isFirst ?? true;
    if (!atStackRoot) {
      await nav.pushReplacement(route);
    } else {
      await nav.push(route);
    }
  }

  static Future<void> toDeckManager(
    BuildContext context,
    CardRepository repository, {
    int? initialProfileId,
  }) {
    return _pushOrReplace(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DeckManagerScreen(
          repository: repository,
          initialProfileId: initialProfileId,
        ),
      ),
    );
  }

  static Future<void> toDashboard(
    BuildContext context,
    CardRepository repository,
  ) {
    return _pushOrReplace(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(repository: repository),
      ),
    );
  }

  static Future<void> toSettings(
    BuildContext context,
    CardRepository repository,
  ) {
    return _pushOrReplace(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(repository: repository),
      ),
    );
  }

  static Future<void> toSentenceDecoder(
    BuildContext context,
    CardRepository repository,
    LanguageProfile profile,
  ) {
    return _pushOrReplace(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SentenceDecoderScreen(
          profile: profile,
          repository: repository,
        ),
      ),
    );
  }

  static Future<void> toStudy(
    BuildContext context,
    CardRepository repository,
    LanguageProfile profile,
  ) {
    final s = context.nexusSettings;
    return _pushOrReplace(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StudySessionScreen(
          profile: profile,
          repository: repository,
          sMax: s.sMax,
          effectsEnabled: s.effectsEnabled,
          ratingDisplayStyle: s.ratingStyle,
          studyDirection: s.studyDirection,
        ),
      ),
    );
  }
}

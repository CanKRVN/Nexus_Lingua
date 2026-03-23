import 'package:flutter/material.dart';

import 'core/database/card_repository.dart';
import 'core/settings/nexus_settings.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/theme_service.dart';
import 'features/home/home_screen.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = NexusSettings();
  await settings.load();
  final repository = CardRepository();
  await repository.bootstrapPersistence();
  final themeProvider = ThemeProvider(ThemeService());
  await themeProvider.load();
  runApp(
    NexusLinguaApp(
      settings: settings,
      themeProvider: themeProvider,
      repository: repository,
    ),
  );
}

/// Root app: settings + theme scope + dual themes + [HomeScreen].
class NexusLinguaApp extends StatelessWidget {
  /// Creates the app.
  const NexusLinguaApp({
    super.key,
    required this.settings,
    required this.themeProvider,
    required this.repository,
  });

  /// Persisted UI preferences.
  final NexusSettings settings;

  /// Dark / light mode + DB persistence.
  final ThemeProvider themeProvider;

  /// Shared data access (opened once at startup for theme load).
  final CardRepository repository;

  @override
  Widget build(BuildContext context) {
    return NexusSettingsScope(
      notifier: settings,
      child: ThemeProviderScope(
        notifier: themeProvider,
        child: ListenableBuilder(
          listenable: themeProvider,
          builder: (context, _) {
            return MaterialApp(
              title: 'Nexus Lingua',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode == ThemeMode.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              home: HomeScreen(repository: repository),
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );
  }
}

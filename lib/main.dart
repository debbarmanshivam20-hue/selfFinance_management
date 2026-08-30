import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'models/app_settings_model.dart';
import 'providers/core_providers.dart';
import 'repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is designed for phones in portrait; locking it avoids layouts
  // that were never designed for landscape.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  AppDatabase? database;
  try {
    // Opening the database runs the migration and seeds defaults on a fresh
    // install. Reading settings forces that to complete before the first
    // frame, so the app never paints against a half-built schema.
    database = AppDatabase();
    final settings = await SettingsRepository(database).read();

    runApp(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(settings),
        ],
        child: const FinVaultApp(),
      ),
    );
  } catch (_) {
    // A failure here means the database file itself is unusable. Show a
    // recoverable screen rather than crashing to a blank window. The
    // underlying exception is deliberately not surfaced - it can contain
    // file paths and offers the user nothing actionable.
    await database?.close();
    runApp(const _StartupFailureApp());
  }
}

/// Last-resort screen shown when local storage cannot be opened.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 56),
                  const SizedBox(height: 24),
                  Text(
                    'Local storage is unavailable',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${AppInfo.name} could not open its database on this '
                    'device. Restarting the app usually fixes this. If it '
                    'keeps happening, free up storage space and try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
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

/// Exposed for tests: builds the app against an existing database.
ProviderScope buildAppForTesting({
  required AppDatabase database,
  required AppSettingsModel settings,
}) {
  return ProviderScope(
    overrides: <Override>[
      databaseProvider.overrideWithValue(database),
      initialSettingsProvider.overrideWithValue(settings),
    ],
    child: const FinVaultApp(),
  );
}

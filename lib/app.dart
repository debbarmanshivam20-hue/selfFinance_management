import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'providers/core_providers.dart';

class FinVaultApp extends ConsumerStatefulWidget {
  const FinVaultApp({super.key});

  @override
  ConsumerState<FinVaultApp> createState() => _FinVaultAppState();
}

class _FinVaultAppState extends ConsumerState<FinVaultApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Today" is captured once per session. Refreshing it when the app comes
    // back to the foreground stops a session left open overnight from
    // reporting yesterday's date on the dashboard.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(nowProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const AppShell(),
      builder: (context, child) {
        // Respect the user's font scale, but clamp the extremes so the
        // dashboard's dense number cards cannot overflow.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/initialization_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget: theme mode, localization, and navigation shell.
class SmartAgroConnectApp extends ConsumerWidget {
  const SmartAgroConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(initializationProvider);
    final themeMode = ref.watch(themeModeProvider);

    return init.when(
      data: (_) {
        final router = ref.watch(goRouterProvider);

        return MaterialApp.router(
          title: 'SmartAgro Connect',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          routerConfig: router,
          locale: const Locale('en', 'NG'),
          supportedLocales: const [
            Locale('en', 'NG'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Startup error: $e')),
        ),
      ),
    );
  }
}

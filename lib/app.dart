import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/di/initialization_provider.dart';
import 'core/errors/friendly_error.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Jailbreak / root blocker
// ---------------------------------------------------------------------------
class _JailbreakBlocker extends StatelessWidget {
  const _JailbreakBlocker();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.security_rounded, size: 72, color: Color(0xFFB00020)),
              SizedBox(height: 24),
              Text(
                'Security Alert',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'SmartAgro Connect has detected that this device '
                'may be compromised (rooted or jailbroken). '
                'For the security of your data, the app cannot '
                'run on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Root widget: theme mode, localization, and navigation shell.
class SmartAgroConnectApp extends ConsumerWidget {
  const SmartAgroConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(initializationProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isJailbroken =
        ref.watch(jailbreakDetectedProvider).valueOrNull ?? false;

    return init.when(
      data: (_) {
        final router = ref.watch(goRouterProvider);

        return MaterialApp.router(
          title: AppEnv.appName,
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
          builder: (context, child) {
            if (isJailbroken) return const _JailbreakBlocker();
            if (!AppEnv.isProd) {
              return Banner(
                message: AppEnv.isStaging ? 'STAGING' : 'DEV',
                location: BannerLocation.topEnd,
                color: AppEnv.isStaging
                    ? const Color(0xFFF57C00)
                    : const Color(0xFF1565C0),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(
          body: Center(
              child: Text('SmartAgro could not start. ${friendlyError(e)}',
                  textAlign: TextAlign.center)),
        ),
      ),
    );
  }
}

import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_env.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/initialization_provider.dart';
import '../../core/services/app_lock.dart';

bool _fcmSupported() => kIsWeb || (!Platform.isWindows && !Platform.isLinux);

final _notificationStatusProvider =
    FutureProvider.autoDispose<AuthorizationStatus>((ref) async {
  if (!_fcmSupported()) return AuthorizationStatus.denied;
  if (Firebase.apps.isEmpty) return AuthorizationStatus.denied;
  final s = await FirebaseMessaging.instance.getNotificationSettings();
  return s.authorizationStatus;
});

const _kPriceAlerts = 'price_alerts_enabled';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _openPage(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  Future<void> _toggleAppLock(bool enable) async {
    final result = await ref.read(appLockProvider.notifier).setEnabled(enable);
    if (!mounted) return;
    final message = switch (result) {
      AppLockSetupResult.enabled =>
        'App lock is on. SmartAgro will ask for your fingerprint, face or PIN.',
      AppLockSetupResult.disabled => 'App lock is off.',
      AppLockSetupResult.cancelled => 'App lock was not turned on.',
      AppLockSetupResult.unsupported =>
        'Set up a fingerprint, face unlock or screen lock in your phone '
            'settings first.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _priceAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPriceAlerts();
  }

  Future<void> _loadPriceAlerts() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (!mounted) return;
    setState(() => _priceAlerts = prefs.getBool(_kPriceAlerts) ?? true);
  }

  Future<void> _handleNotificationToggle(bool isCurrentlyOn) async {
    if (!_fcmSupported()) return;
    if (isCurrentlyOn) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Disable notifications'),
          content: const Text(
            'To turn off notifications, go to your device Settings'
            ' > Apps > SmartAgro Connect > Notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      ref.read(appLockProvider.notifier).allowNextReturn();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
    ref.invalidate(_notificationStatusProvider);
  }

  Future<void> _handlePriceAlertsToggle(bool next) async {
    setState(() => _priceAlerts = next);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kPriceAlerts, next);
    // The backend checks this before sending a price alert. (It used to
    // subscribe to a 'price-alerts' topic that nothing ever sent to.)
    final uid = ref.read(authSessionProvider)?.id;
    if (uid == null) return;
    try {
      await ref.read(firestoreServiceProvider).setPriceAlertsEnabled(uid, next);
    } catch (_) {
      if (mounted) {
        setState(() => _priceAlerts = !next);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't save that. Check your connection.")));
      }
      await prefs.setBool(_kPriceAlerts, !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final notifAsync = ref.watch(_notificationStatusProvider);
    final notifOn = notifAsync.valueOrNull == AuthorizationStatus.authorized ||
        notifAsync.valueOrNull == AuthorizationStatus.provisional;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Appearance'),
            subtitle: Text('Switch between light, dark, and system default.'),
          ),
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (v) {
              if (v != null) ref.read(themeModeProvider.notifier).setMode(v);
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('System default'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: notifOn,
            onChanged: notifAsync.isLoading
                ? null
                : (_) => _handleNotificationToggle(notifOn),
            title: const Text('Push notifications'),
            subtitle: Text(
              notifAsync.isLoading
                  ? 'Checking…'
                  : notifOn
                      ? 'Enabled'
                      : 'Tap to enable',
            ),
          ),
          SwitchListTile(
            value: _priceAlerts,
            onChanged: _handlePriceAlertsToggle,
            title: const Text('Price alerts'),
            subtitle: const Text(
                'Notify me when a price I set an alert for is reached'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            value: ref.watch(appLockProvider).enabled,
            onChanged: _toggleAppLock,
            title: const Text('App lock'),
            subtitle: const Text(
                'Ask for your fingerprint, face or phone PIN when opening '
                'SmartAgro'),
          ),
          const ListTile(
            leading: Icon(Icons.language_outlined),
            title: Text('Language'),
            subtitle: Text('English (Nigeria)'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _openPage(AppEnv.privacyPolicyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of use'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => _openPage(AppEnv.termsUrl),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text(AppEnv.appVersion),
          ),
        ],
      ),
    );
  }
}

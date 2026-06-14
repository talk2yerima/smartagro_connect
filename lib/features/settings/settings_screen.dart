import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/initialization_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
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
            value: true,
            onChanged: (_) {},
            title: const Text('Push notifications'),
            subtitle: const Text('FCM wiring in lib/core/services/push_service.dart'),
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Price alerts'),
            subtitle: const Text('Requires background worker + topic subscriptions'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Security'),
            subtitle: Text('Biometrics / PIN can wrap SecureTokenStore'),
          ),
          const ListTile(
            leading: Icon(Icons.language_outlined),
            title: Text('Language'),
            subtitle: Text('English (Nigeria) baseline — add intl ARB files next'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/auth_providers.dart';
import '../utils/app_logger.dart';

/// Fingerprint / face (or the phone's PIN) unlock for SmartAgro.
///
/// When on, the app locks on a cold start and whenever it comes back after
/// [relockAfter] in the background. It only ever applies to a signed-in
/// person; signing out (from the lock screen too) always works, so nobody
/// can be locked out of their account by a broken fingerprint sensor.
class AppLockState {
  const AppLockState({required this.enabled, required this.locked});

  final bool enabled;
  final bool locked;

  AppLockState copyWith({bool? enabled, bool? locked}) => AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
      );
}

/// What happened when someone tried to switch the lock on.
enum AppLockSetupResult { enabled, disabled, cancelled, unsupported }

class AppLockController extends StateNotifier<AppLockState>
    with WidgetsBindingObserver {
  AppLockController(this._prefs, {LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication(),
        super(AppLockState(
          enabled: _prefs.getBool(prefsKey) ?? false,
          // Locked from the first frame on a cold start when switched on.
          locked: _prefs.getBool(prefsKey) ?? false,
        )) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const prefsKey = 'app_lock_enabled';

  /// Time in the background before the app asks again. Short trips (taking
  /// a listing photo, answering a call) don't re-lock.
  static const relockAfter = Duration(seconds: 60);

  final SharedPreferences _prefs;
  final LocalAuthentication _auth;
  DateTime? _backgroundedAt;

  /// The system unlock sheet briefly pauses the app; ignore those events.
  bool _authenticating = false;

  @override
  // Not named `state`: that would shadow this notifier's own state.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (!state.enabled || _authenticating) return;
    if (lifecycle == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && DateTime.now().difference(since) >= relockAfter) {
        state = state.copyWith(locked: true);
      }
    }
  }

  /// Whether this phone has a fingerprint, face or screen lock to use.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      log.w('[AppLock] support check failed: $e');
      return false;
    }
  }

  /// Shows the system unlock sheet. Returns true when the person passed.
  Future<bool> _authenticate(String reason) async {
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Allow the phone's PIN/pattern as a fallback to fingerprint/face.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      log.w('[AppLock] authenticate failed: ${e.code}');
      return false;
    } catch (e) {
      log.w('[AppLock] authenticate failed: $e');
      return false;
    } finally {
      _authenticating = false;
    }
  }

  Future<bool> unlock() async {
    final ok = await _authenticate('Unlock SmartAgro');
    if (ok && mounted) state = state.copyWith(locked: false);
    return ok;
  }

  /// Turns the lock on (after confirming it's really the owner) or off.
  Future<AppLockSetupResult> setEnabled(bool enable) async {
    if (!enable) {
      await _prefs.setBool(prefsKey, false);
      state = const AppLockState(enabled: false, locked: false);
      return AppLockSetupResult.disabled;
    }
    if (!await isSupported()) return AppLockSetupResult.unsupported;
    if (!await _authenticate('Confirm it is you to turn on app lock')) {
      return AppLockSetupResult.cancelled;
    }
    await _prefs.setBool(prefsKey, true);
    state = const AppLockState(enabled: true, locked: false);
    return AppLockSetupResult.enabled;
  }

  /// Called on sign-out: the next person starts unlocked.
  void clearLock() {
    if (state.locked) state = state.copyWith(locked: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(ref.watch(loadedSharedPreferencesProvider));
});

/// Covers the app with the lock screen while it is locked and someone is
/// signed in. The app stays mounted underneath, so unlocking returns to
/// exactly where the person was.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final signedIn = ref.watch(authSessionProvider) != null;
    final showLock = lock.enabled && lock.locked && signedIn;
    return Stack(
      children: [
        ExcludeSemantics(excluding: showLock, child: child),
        if (showLock) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Ask straight away; the button is there if they cancel.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _signOut() async {
    ref.read(appLockProvider.notifier).clearLock();
    await ref.read(authSessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fingerprint_rounded,
                    size: 52, color: scheme.primary),
              ),
              const SizedBox(height: 24),
              Text('SmartAgro is locked',
                  style: text.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? "That didn't work. Try again, or use your phone's PIN."
                    : 'Use your fingerprint, face or phone PIN to continue.',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_busy ? 'Waiting…' : 'Unlock'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out instead'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

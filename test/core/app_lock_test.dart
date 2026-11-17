import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagro_connect/core/services/app_lock.dart';

class MockAuth extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuth auth;

  Future<AppLockController> controller({bool enabled = false}) async {
    SharedPreferences.setMockInitialValues(
        {if (enabled) AppLockController.prefsKey: true});
    final prefs = await SharedPreferences.getInstance();
    return AppLockController(prefs, auth: auth);
  }

  void authenticateReturns(bool result) {
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        )).thenAnswer((_) async => result);
  }

  setUp(() {
    auth = MockAuth();
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
  });

  test('starts unlocked and off by default', () async {
    final c = await controller();
    expect(c.state.enabled, isFalse);
    expect(c.state.locked, isFalse);
  });

  test('a cold start is locked when app lock is on', () async {
    final c = await controller(enabled: true);
    expect(c.state.enabled, isTrue);
    expect(c.state.locked, isTrue);
  });

  test('turning it on asks the owner first and saves the choice', () async {
    authenticateReturns(true);
    final c = await controller();

    expect(await c.setEnabled(true), AppLockSetupResult.enabled);
    expect(c.state.enabled, isTrue);
    expect(c.state.locked, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppLockController.prefsKey), isTrue);
  });

  test('cancelling the fingerprint check leaves it off', () async {
    authenticateReturns(false);
    final c = await controller();

    expect(await c.setEnabled(true), AppLockSetupResult.cancelled);
    expect(c.state.enabled, isFalse);
  });

  test('phones with no screen lock are told to set one up', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);
    final c = await controller();

    expect(await c.setEnabled(true), AppLockSetupResult.unsupported);
    verifyNever(() =>
        auth.authenticate(localizedReason: any(named: 'localizedReason')));
  });

  test('unlocking with a good fingerprint opens the app', () async {
    authenticateReturns(true);
    final c = await controller(enabled: true);

    expect(await c.unlock(), isTrue);
    expect(c.state.locked, isFalse);
  });

  test('a failed fingerprint keeps it locked', () async {
    authenticateReturns(false);
    final c = await controller(enabled: true);

    expect(await c.unlock(), isFalse);
    expect(c.state.locked, isTrue);
  });

  test('a quick trip out of the app does not re-lock it', () async {
    authenticateReturns(true);
    final c = await controller(enabled: true);
    await c.unlock();

    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(c.state.locked, isFalse);
  });

  test('turning it off unlocks and saves the choice', () async {
    final c = await controller(enabled: true);

    expect(await c.setEnabled(false), AppLockSetupResult.disabled);
    expect(c.state, isA<AppLockState>());
    expect(c.state.enabled, isFalse);
    expect(c.state.locked, isFalse);
  });
}

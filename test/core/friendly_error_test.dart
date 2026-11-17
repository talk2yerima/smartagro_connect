import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/errors/failures.dart';
import 'package:smartagro_connect/core/errors/friendly_error.dart';

void main() {
  test('keeps messages we wrote for people', () {
    expect(friendlyError(const ValidationFailure('Enter a valid OTP')),
        'Enter a valid OTP');
  });

  test('network problems read as offline, not raw exception text', () {
    for (final e in [
      const SocketException('Failed host lookup: firestore.googleapis.com'),
      const NetworkFailure('DioException [connection error]'),
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      Exception('Connection closed before full header was received'),
    ]) {
      expect(friendlyError(e), contains("You're offline"), reason: '$e');
    }
  });

  test('wrong sign-in details get a plain message', () {
    final msg =
        friendlyError(FirebaseAuthException(code: 'invalid-credential'));
    expect(msg, contains("don't match"));
    expect(msg, isNot(contains('firebase')));
  });

  test('permission errors suggest signing in again', () {
    final msg = friendlyError(FirebaseException(
        plugin: 'cloud_firestore', code: 'permission-denied'));
    expect(msg, contains('permission'));
  });

  test('anything unknown falls back to a generic sentence', () {
    expect(friendlyError(StateError('null check operator')),
        'Something went wrong. Please try again.');
  });
}

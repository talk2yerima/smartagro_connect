import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'failures.dart';

/// Turns any error into one short sentence a farmer or buyer can act on.
///
/// Screens used to show raw exception text such as
/// "[cloud_firestore/unavailable] The service is currently unavailable" or
/// "Exception: SocketException ...". Use this wherever an error reaches the
/// screen; log the original error separately for debugging.
String friendlyError(Object error) {
  // Our own failures already carry a message written for people, except
  // network/server ones, which still come from low-level text.
  if (error is ValidationFailure || error is AuthFailure) {
    return (error as Failure).message;
  }
  if (error is NetworkFailure) return _offline;
  if (error is ServerFailure) return _server;
  if (error is CacheFailure) return _generic;

  if (error is SocketException || error is TimeoutException) return _offline;

  if (error is FirebaseAuthException) return _authMessage(error.code);
  // Photo / voice-note uploads (Firebase Storage).
  if (error is FirebaseException && error.plugin == 'firebase_storage') {
    switch (error.code) {
      case 'unauthorized':
      case 'unauthenticated':
        return "You don't have permission to upload this. Try signing out "
            'and back in.';
      case 'retry-limit-exceeded':
        return _offline;
    }
    // Includes a missing storage bucket, which the person can't fix.
    return "Uploads aren't working right now. Please try again later.";
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return _offline;
      case 'permission-denied':
      case 'unauthenticated':
        return "You don't have permission to do that. Try signing out and "
            'back in.';
      case 'not-found':
        return 'That item no longer exists. It may have been removed.';
      case 'resource-exhausted':
        return 'Too many requests right now. Please wait a minute and try '
            'again.';
    }
    return _generic;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('host lookup') ||
      text.contains('connection')) {
    return _offline;
  }
  return _generic;
}

const _offline =
    "You're offline or the connection is weak. Check your internet and try "
    'again.';
const _server = 'Our server had a problem. Please try again in a moment.';
const _generic = 'Something went wrong. Please try again.';

String _authMessage(String code) => switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-email' =>
        'That email and password don\'t match. Check them and try again.',
      'email-already-in-use' =>
        'An account with this email already exists. Try signing in instead.',
      'weak-password' => 'Choose a stronger password of at least 6 characters.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      'too-many-requests' =>
        'Too many attempts. Wait a few minutes, then try again.',
      'network-request-failed' => _offline,
      _ => 'Sign-in failed. Please try again.',
    };

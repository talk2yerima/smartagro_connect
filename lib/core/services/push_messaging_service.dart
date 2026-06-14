import 'dart:io';

import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method) per FCM requirements.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are logged; show a local notification here if needed
  // using flutter_local_notifications (add to pubspec when integrating).
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Push notification bootstrap — fully wired to Firebase Cloud Messaging.
///
/// Call [register] once during app initialisation (inside initializationProvider).
/// The app must have Firebase initialised first (see main.dart).
///
/// Responsibilities:
///   1. Request notification permission from the user.
///   2. Retrieve and expose the device FCM token (send to your backend).
///   3. Register the background message handler.
///   4. Listen for foreground messages and surface them as in-app banners.
///   5. Handle notification taps (background + terminated) for deep-linking.
class PushMessagingService {
  PushMessagingService._();
  static final PushMessagingService instance = PushMessagingService._();

  String? _fcmToken;

  /// The device's FCM registration token.
  /// Available after [register] completes.  Send this to your backend so it
  /// can target push notifications at this specific device.
  String? get fcmToken => _fcmToken;

  /// Callback invoked when a notification is tapped (background or terminated).
  /// Wire this to your GoRouter to navigate to the relevant screen.
  void Function(RemoteMessage)? onNotificationTap;

  /// Callback invoked when a foreground message arrives.
  /// Use this to show an in-app banner (SnackBar, overlay, etc.).
  void Function(RemoteMessage)? onForegroundMessage;

  Future<void> register() async {
    // firebase_messaging only supports Android, iOS, macOS, and web.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('[Push] Firebase Messaging not supported on this platform — skipped.');
      return;
    }

    // Skip silently if Firebase is not configured.
    if (Firebase.apps.isEmpty) {
      debugPrint('[Push] Firebase not initialised — push notifications skipped.');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // 1. Request permission (iOS requires this; Android 13+ also needs it).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Notification permission denied by user.');
      return;
    }

    // 2. Get device token.
    _fcmToken = await messaging.getToken();
    debugPrint('[Push] FCM token: $_fcmToken');
    // TODO: POST _fcmToken to your backend: PUT /api/users/me/device-token

    // Refresh token when FCM rotates it.
    messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('[Push] FCM token refreshed: $token');
      // TODO: POST updated token to backend.
    });

    // 3. Background message handler (must be registered before any message arrives).
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Foreground messages — FCM doesn't show a notification bar when the
    //    app is in the foreground; use flutter_local_notifications for that.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] Foreground message: ${message.notification?.title}');
      onForegroundMessage?.call(message);
    });

    // 5a. Tapped while app was in background (resumed from system tray).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] Notification tapped (background): ${message.data}');
      onNotificationTap?.call(message);
    });

    // 5b. Tapped while app was terminated (cold start from notification).
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[Push] App opened from terminated via notification: ${initial.data}');
      onNotificationTap?.call(initial);
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/nigerian_states.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/geo.dart';

/// Why a location couldn't be read, in words for the person.
class LocationProblem implements Exception {
  const LocationProblem(this.message, {this.openSettings = false});

  final String message;

  /// True when only the phone's settings can fix it (permission denied
  /// forever, or location switched off).
  final bool openSettings;

  @override
  String toString() => message;
}

/// A place described for people: "Gashua, Bade" in "Yobe".
typedef PlaceName = ({String label, String state});

/// The phone's location: one-off fixes, place names, and live tracking for
/// deliveries.
class LocationService {
  /// Asks for permission if needed. Throws [LocationProblem] with a message
  /// the screen can show as it is. [beforeSystemPrompt] runs just before the
  /// system permission dialog (the app lock uses it to not relock).
  Future<void> ensurePermission({VoidCallback? beforeSystemPrompt}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationProblem(
          'Location is switched off. Turn it on to use your position.',
          openSettings: true);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      beforeSystemPrompt?.call();
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationProblem('Location permission was not given.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationProblem(
          'Location permission is blocked. Allow it for SmartAgro in Settings.',
          openSettings: true);
    }
  }

  /// Where the phone is now.
  Future<GeoPoint2> current({VoidCallback? beforeSystemPrompt}) async {
    await ensurePermission(beforeSystemPrompt: beforeSystemPrompt);
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoPoint2(p.latitude, p.longitude);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint2(last.latitude, last.longitude);
      throw const LocationProblem(
          'Could not find your position. Move to an open area and try again.');
    }
  }

  /// Where the phone is, only if location is already allowed (never shows
  /// a permission dialog). Null otherwise.
  Future<GeoPoint2?> currentIfAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final p = await Geolocator.checkPermission();
      if (p != LocationPermission.always &&
          p != LocationPermission.whileInUse) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return GeoPoint2(last.latitude, last.longitude);
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15)),
      );
      return GeoPoint2(now.latitude, now.longitude);
    } catch (e) {
      log.w('[Location] currentIfAllowed failed: $e');
      return null;
    }
  }

  /// A short name for a map point, using the phone's own geocoder (no key,
  /// no cost). Null when offline or the area has no name on record.
  Future<PlaceName?> describe(GeoPoint2 point) async {
    try {
      final marks = await placemarkFromCoordinates(point.lat, point.lng)
          .timeout(const Duration(seconds: 8));
      if (marks.isEmpty) return null;
      final m = marks.first;
      final parts = <String>[];
      for (final s in [m.name, m.street, m.subLocality, m.locality]) {
        final t = (s ?? '').trim();
        // Geocoders often return a plus-code or a lone number as the name.
        if (t.isEmpty || t.contains('+') || RegExp(r'^\d+$').hasMatch(t)) {
          continue;
        }
        if (!parts.contains(t)) parts.add(t);
      }
      final area = (m.subAdministrativeArea ?? '').trim();
      if (parts.length < 2 && area.isNotEmpty && !parts.contains(area)) {
        parts.add(area);
      }
      return (
        label: parts.take(3).join(', '),
        state: matchState(m.administrativeArea) ?? '',
      );
    } catch (e) {
      log.w('[Location] describe failed: $e');
      return null;
    }
  }

  /// Turns a geocoder's region ("Yobe State", "Federal Capital Territory")
  /// into one of [kNigerianStates], or null.
  static String? matchState(String? region) {
    final r = (region ?? '')
        .toLowerCase()
        .replaceAll(' state', '')
        .replaceAll('state of ', '')
        .trim();
    if (r.isEmpty) return null;
    if (r.contains('capital territory') || r == 'fct' || r == 'abuja') {
      return kNigerianStates.firstWhere((s) => s.startsWith('FCT'));
    }
    for (final s in kNigerianStates) {
      if (s.toLowerCase() == r) return s;
    }
    return null;
  }

  /// Live position for a delivery: about every 15 s or 50 m. On Android it
  /// runs as a foreground service with a visible notification, so it keeps
  /// going while the driver navigates in Google Maps.
  Stream<Position> track() {
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
            intervalDuration: const Duration(seconds: 15),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Sharing your delivery location',
              notificationText:
                  'The buyer and seller can see where the produce is.',
              notificationIcon: AndroidResource(name: 'ic_stat_truck'),
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 50);
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

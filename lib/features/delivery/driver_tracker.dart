import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/geo.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/haulage_job.dart';

/// What the transporter's phone is doing with location right now.
class TrackerState {
  const TrackerState({
    this.jobId,
    this.position,
    this.speedKmh,
    this.lastSentAt,
    this.problem,
  });

  /// The delivery whose location is being shared, or null when off.
  final String? jobId;
  final GeoPoint2? position;
  final double? speedKmh;
  final DateTime? lastSentAt;

  /// Why sharing stopped or couldn't start, for the screen.
  final LocationProblem? problem;

  bool get sharing => jobId != null;
}

/// When to send a new position: the first fix, then at most every
/// [minGap] if the truck moved at least [minMoveKm], and at least every
/// [maxGap] while it is standing still (so followers see it is alive).
/// Keeps data use and database writes low on long trips.
bool shouldSendPosition({
  required DateTime now,
  required GeoPoint2 here,
  DateTime? lastAt,
  GeoPoint2? lastPoint,
  Duration minGap = const Duration(seconds: 20),
  Duration maxGap = const Duration(seconds: 90),
  double minMoveKm = 0.05,
}) {
  if (lastAt == null || lastPoint == null) return true;
  final gap = now.difference(lastAt);
  if (gap >= maxGap) return true;
  return gap >= minGap && straightLineKm(lastPoint, here) >= minMoveKm;
}

/// Shares the transporter's live location on their active delivery.
///
/// Lives for the whole session (not one screen), starts by itself when the
/// transporter has a delivery under way, and stops when it is delivered or
/// handed back. On Android it runs as a foreground service with a visible
/// notification, so it keeps going during Google Maps navigation.
class DriverTracker extends Notifier<TrackerState> {
  StreamSubscription<Position>? _sub;
  DateTime? _lastSentAt;
  GeoPoint2? _lastSentPoint;

  /// Jobs whose automatic start failed (e.g. permission refused): don't
  /// nag again; the delivery screen offers a button instead.
  final _autoStartRefused = <String>{};

  @override
  TrackerState build() {
    final user = ref.watch(authSessionProvider
        .select((u) => u == null ? null : (id: u.id, role: u.role)));
    ref.onDispose(_cancel);
    if (user != null && user.role == UserRole.transporter) {
      // After build returns: _sync reads and sets this notifier's state.
      ref.listen<AsyncValue<List<HaulageJob>>>(
          myHaulageJobsProvider,
          (_, next) =>
              Future.microtask(() => _sync(next.valueOrNull ?? const [])),
          fireImmediately: true);
    }
    return const TrackerState();
  }

  void _sync(List<HaulageJob> mine) {
    final active = mine.where((j) => j.isActive).toList();
    final current = state.jobId;
    if (current != null && !active.any((j) => j.id == current)) {
      stop();
    }
    if (state.jobId == null && active.isNotEmpty) {
      final job = active.first;
      if (!_autoStartRefused.contains(job.id)) {
        unawaited(start(job.id, automatic: true));
      }
    }
  }

  /// Starts sharing for [jobId] (asks for location permission if needed).
  Future<void> start(String jobId, {bool automatic = false}) async {
    if (state.jobId == jobId && _sub != null) return;
    _cancel();
    final location = ref.read(locationServiceProvider);
    try {
      await location.ensurePermission(
          beforeSystemPrompt: () =>
              ref.read(appLockProvider.notifier).allowNextReturn());
    } on LocationProblem catch (p) {
      if (automatic) _autoStartRefused.add(jobId);
      state = TrackerState(problem: p);
      return;
    }
    _autoStartRefused.remove(jobId);
    state = TrackerState(jobId: jobId);
    _sub = location.track().listen(
      (p) => _onPosition(jobId, p),
      onError: (Object e) {
        log.w('[Tracker] location stream error: $e');
        _cancel();
        state = TrackerState(
            problem: e is LocationProblem
                ? e
                : const LocationProblem(
                    'Live location stopped. Tap to share it again.'));
      },
    );
  }

  void _onPosition(String jobId, Position p) {
    final here = GeoPoint2(p.latitude, p.longitude);
    final speed = p.speed >= 0 ? p.speed * 3.6 : null;
    final now = DateTime.now();
    final send = shouldSendPosition(
        now: now, here: here, lastAt: _lastSentAt, lastPoint: _lastSentPoint);
    if (send) {
      _lastSentAt = now;
      _lastSentPoint = here;
      unawaited(ref
          .read(firestoreServiceProvider)
          .shareDriverLocation(jobId, here.lat, here.lng, speed)
          .catchError((Object e) => log.w('[Tracker] share failed: $e')));
    }
    state = TrackerState(
      jobId: jobId,
      position: here,
      speedKmh: speed,
      lastSentAt: _lastSentAt,
    );
  }

  void stop() {
    _cancel();
    state = const TrackerState();
  }

  void _cancel() {
    _sub?.cancel();
    _sub = null;
    _lastSentAt = null;
    _lastSentPoint = null;
  }
}

final driverTrackerProvider =
    NotifierProvider<DriverTracker, TrackerState>(DriverTracker.new);

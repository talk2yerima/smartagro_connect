import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/utils/geo.dart';
import 'package:smartagro_connect/data/services/location_service.dart';
import 'package:smartagro_connect/domain/delivery_pricing.dart';
import 'package:smartagro_connect/domain/entities/haulage_job.dart';
import 'package:smartagro_connect/features/delivery/delivery_screen.dart';
import 'package:smartagro_connect/features/delivery/driver_tracker.dart';

HaulageJob _job(String status, {Map<String, dynamic>? loc}) =>
    HaulageJob.fromMap('SA-1', {
      'status': status,
      'pickup': {'label': 'A', 'state': 'Yobe', 'lat': 12.0, 'lng': 11.0},
      'dropoff': {'label': 'B', 'state': 'Kano', 'lat': 12.0, 'lng': 9.0},
      'distanceKm': 280.0,
      'weightKg': 800,
      if (loc != null) 'driverLocation': loc,
    });

void main() {
  test('fare suggestion grows with distance and load, with a floor', () {
    expect(suggestedFareNgn(0, 100), 0);
    expect(suggestedFareNgn(5, 100), 3000); // short trip: the minimum
    expect(suggestedFareNgn(100, 300), 12000); // 100 km × ₦120
    expect(suggestedFareNgn(100, 1500), 20000); // light truck
    expect(suggestedFareNgn(100, 8000), 35000);
    expect(suggestedFareNgn(100, 20000), 50000);
    expect(suggestedFareNgn(101.3, 300) % 500, 0); // rounded to ₦500
    expect(vehicleFor(400), 'Pickup or van');
    expect(vehicleFor(30000), 'Trailer');
  });

  test('geocoder regions become our state names', () {
    expect(LocationService.matchState('Yobe State'), 'Yobe');
    expect(LocationService.matchState('Akwa Ibom'), 'Akwa Ibom');
    expect(LocationService.matchState('Federal Capital Territory'),
        startsWith('FCT'));
    expect(LocationService.matchState('Ontario'), isNull);
    expect(LocationService.matchState(null), isNull);
  });

  test('location is sent at a gentle rate', () {
    final t0 = DateTime(2026, 11, 18, 10);
    const a = GeoPoint2(12.0, 11.0);
    const near = GeoPoint2(12.0001, 11.0); // ~11 m
    const far = GeoPoint2(12.002, 11.0); // ~220 m
    expect(shouldSendPosition(now: t0, here: a), isTrue);
    bool after(int s, GeoPoint2 p) => shouldSendPosition(
        now: t0.add(Duration(seconds: s)), here: p, lastAt: t0, lastPoint: a);
    expect(after(5, far), isFalse); // too soon
    expect(after(25, near), isFalse); // hardly moved
    expect(after(25, far), isTrue);
    expect(after(95, a), isTrue); // standing still: still a heartbeat
  });

  test('what is left of the trip depends on the stage', () {
    const truck = {
      'lat': 12.0,
      'lng': 10.0,
      'updatedAt': '2026-11-18T10:00:00'
    };
    final before = remainingTrip(_job('accepted', loc: truck),
        _job('accepted', loc: truck).driverLocation!.point)!;
    final after = remainingTrip(_job('picked_up', loc: truck),
        _job('picked_up', loc: truck).driverLocation!.point)!;
    // Before pickup: to the pickup, then the whole trip.
    expect(before.km, greaterThan(280));
    // After pickup: only to the drop-off (about half way here).
    expect(after.km, lessThan(before.km));
    expect(after.time.inMinutes, greaterThan(0));
    expect(remainingTrip(_job('open'), null), isNull);
    expect(remainingTrip(_job('delivered', loc: truck), const GeoPoint2(1, 1)),
        isNull);
  });
}

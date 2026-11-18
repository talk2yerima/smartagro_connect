import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/utils/geo.dart';
import 'package:smartagro_connect/domain/entities/haulage_job.dart';

void main() {
  // Gashua (Yobe) and Kano: about 280 km apart in a straight line.
  const gashua = GeoPoint2(12.8706, 11.0465);
  const kano = GeoPoint2(12.0022, 8.5920);

  test('straight-line distance between two towns', () {
    final km = straightLineKm(gashua, kano);
    expect(km, inInclusiveRange(270, 290));
    expect(straightLineKm(gashua, gashua), closeTo(0, 0.001));
  });

  test('road estimate is longer than the straight line', () {
    expect(estimatedRoadKm(gashua, kano),
        closeTo(straightLineKm(gashua, kano) * roadFactor, 0.001));
  });

  test('drive time at truck speed, and friendly formatting', () {
    expect(estimatedDriveTime(90).inMinutes, 120);
    expect(formatDuration(const Duration(minutes: 200)), '3 h 20 min');
    expect(formatDuration(const Duration(minutes: 45)), '45 min');
    expect(formatDuration(const Duration(minutes: 120)), '2 h');
    expect(formatDistance(0.35), '350 m');
    expect(formatDistance(4.26), '4.3 km');
    expect(formatDistance(286.4), '286 km');
  });

  test('a job reads its places, status and live location', () {
    final job = HaulageJob.fromMap('j1', {
      'orderId': 'SA-1',
      'description': '50 kg of Fresh Tomato',
      'weightKg': 50,
      'requesterId': 's1',
      'sellerId': 's1',
      'buyerId': 'b1',
      'pickup': {
        'label': 'Gashua market',
        'state': 'Yobe',
        'lat': 12.87,
        'lng': 11.04
      },
      'dropoff': {'label': 'Kano', 'state': 'Kano', 'lat': 12.0, 'lng': 8.59},
      'distanceKm': 360.5,
      'offerNgn': 25000,
      'status': 'picked_up',
      'transporterId': 't1',
      'driverLocation': {
        'lat': 12.5,
        'lng': 10.0,
        'speedKmh': 60,
        'updatedAt': DateTime(2026, 11, 18, 10)
      },
    });
    expect(job.isPickedUp, isTrue);
    expect(job.isActive, isTrue);
    expect(job.nextStop.label, 'Kano');
    expect(job.driverLocation!.speedKmh, 60);
    expect(job.statusLabel, 'On the way to you');
  });
}

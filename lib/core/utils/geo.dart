import 'dart:math' as math;

/// A point on the map.
class GeoPoint2 {
  const GeoPoint2(this.lat, this.lng);

  final double lat;
  final double lng;

  bool get isSet => !(lat == 0 && lng == 0);
}

/// Straight-line ("as the crow flies") distance in km (haversine).
double straightLineKm(GeoPoint2 a, GeoPoint2 b) {
  const earthKm = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthKm * math.asin(math.min(1, math.sqrt(h)));
}

/// Roads wind: a typical Nigerian road trip is ~25-35% longer than the
/// straight line. Used for "about N km by road" until real routing is added.
const roadFactor = 1.3;

double estimatedRoadKm(GeoPoint2 a, GeoPoint2 b) =>
    straightLineKm(a, b) * roadFactor;

/// Average loaded-truck speed used for arrival estimates, in km/h.
const averageTruckKmh = 45.0;

/// Estimated driving time for [roadKm] at [kmh] (default: a loaded truck).
Duration estimatedDriveTime(double roadKm, {double kmh = averageTruckKmh}) =>
    Duration(minutes: (roadKm / kmh * 60).round());

/// "12 km", "1.4 km", "350 m".
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// "45 min", "3 h 20 min".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${math.max(1, m)} min';
  return m == 0 ? '$h h' : '$h h $m min';
}

import 'dart:math' as math;

/// A starting point for what to offer a transporter, from the road
/// distance and the load. Only a suggestion: the person edits it, and the
/// transporter is paid directly.
///
/// Rough 2026 haulage rates in northern Nigeria, per km of the trip:
///   up to 500 kg (pickup / small van)    ₦120
///   up to 2 t (light truck)               ₦200
///   up to 10 t (medium truck)             ₦350
///   above 10 t (trailer)                  ₦500
/// never less than ₦3,000, rounded to the nearest ₦500.
int suggestedFareNgn(double roadKm, int weightKg) {
  if (roadKm <= 0) return 0;
  final perKm = weightKg <= 500
      ? 120
      : weightKg <= 2000
          ? 200
          : weightKg <= 10000
              ? 350
              : 500;
  final raw = math.max(3000.0, roadKm * perKm);
  return ((raw / 500).round() * 500);
}

/// The kind of vehicle a load needs, for job cards.
String vehicleFor(int weightKg) => weightKg <= 500
    ? 'Pickup or van'
    : weightKg <= 2000
        ? 'Light truck'
        : weightKg <= 10000
            ? 'Truck'
            : 'Trailer';

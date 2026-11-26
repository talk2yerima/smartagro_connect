import '../../core/i18n/i18n.dart';
import '../../core/utils/geo.dart';

/// A place on a delivery: a short description and its map position.
class JobPlace {
  const JobPlace({
    required this.label,
    required this.state,
    required this.lat,
    required this.lng,
  });

  factory JobPlace.fromMap(Map<String, dynamic>? m) => JobPlace(
        label: (m?['label'] as String?) ?? '',
        state: (m?['state'] as String?) ?? '',
        lat: (m?['lat'] as num?)?.toDouble() ?? 0,
        lng: (m?['lng'] as num?)?.toDouble() ?? 0,
      );

  final String label;
  final String state;
  final double lat;
  final double lng;

  GeoPoint2 get point => GeoPoint2(lat, lng);

  Map<String, dynamic> toMap() =>
      {'label': label, 'state': state, 'lat': lat, 'lng': lng};
}

/// The transporter's last reported position on an active delivery.
class DriverLocation {
  const DriverLocation({
    required this.lat,
    required this.lng,
    required this.updatedAt,
    this.speedKmh,
  });

  final double lat;
  final double lng;
  final DateTime updatedAt;
  final double? speedKmh;

  GeoPoint2 get point => GeoPoint2(lat, lng);
}

/// A delivery ("haulage job"): produce from a paid order, from pickup to
/// drop-off, carried by a transporter who accepts it.
///
/// open → accepted → picked_up → delivered (or open → cancelled by the
/// person who asked; a transporter can hand an accepted job back to open).
class HaulageJob {
  const HaulageJob({
    required this.id,
    required this.orderId,
    required this.description,
    required this.weightKg,
    required this.requesterId,
    required this.sellerId,
    required this.buyerId,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.offerNgn,
    required this.status,
    required this.createdAt,
    this.notes = '',
    this.transporterId,
    this.transporterName,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.driverLocation,
  });

  factory HaulageJob.fromMap(String id, Map<String, dynamic> m) {
    DateTime? date(Object? v) => v is DateTime
        ? v
        : v is String
            ? DateTime.tryParse(v)
            : null;
    final loc = m['driverLocation'];
    return HaulageJob(
      id: id,
      orderId: (m['orderId'] as String?) ?? '',
      description: (m['description'] as String?) ?? 'Produce',
      weightKg: (m['weightKg'] as num?)?.toInt() ?? 0,
      requesterId: (m['requesterId'] as String?) ?? '',
      sellerId: (m['sellerId'] as String?) ?? '',
      buyerId: (m['buyerId'] as String?) ?? '',
      pickup: JobPlace.fromMap(m['pickup'] as Map<String, dynamic>?),
      dropoff: JobPlace.fromMap(m['dropoff'] as Map<String, dynamic>?),
      distanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 0,
      offerNgn: (m['offerNgn'] as num?)?.toInt() ?? 0,
      notes: (m['notes'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'open',
      createdAt: date(m['createdAt']) ?? DateTime.now(),
      transporterId: m['transporterId'] as String?,
      transporterName: m['transporterName'] as String?,
      acceptedAt: date(m['acceptedAt']),
      pickedUpAt: date(m['pickedUpAt']),
      deliveredAt: date(m['deliveredAt']),
      driverLocation: loc is Map && loc['lat'] is num && loc['lng'] is num
          ? DriverLocation(
              lat: (loc['lat'] as num).toDouble(),
              lng: (loc['lng'] as num).toDouble(),
              speedKmh: (loc['speedKmh'] as num?)?.toDouble(),
              updatedAt: date(loc['updatedAt']) ?? DateTime.now(),
            )
          : null,
    );
  }

  final String id;
  final String orderId;
  final String description;
  final int weightKg;
  final String requesterId;
  final String sellerId;
  final String buyerId;
  final JobPlace pickup;
  final JobPlace dropoff;

  /// Estimated road distance, pickup → drop-off.
  final double distanceKm;

  /// What the requester will pay the transporter (agreed and paid directly
  /// for now; not charged through the app).
  final int offerNgn;
  final String notes;
  final String status;
  final DateTime createdAt;
  final String? transporterId;
  final String? transporterName;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DriverLocation? driverLocation;

  bool get isOpen => status == 'open';
  bool get isAccepted => status == 'accepted';
  bool get isPickedUp => status == 'picked_up';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';

  /// Accepted or on the road: the transporter's phone shares its location.
  bool get isActive => isAccepted || isPickedUp;

  /// Where the truck is heading next: the pickup until collected, then the
  /// drop-off.
  JobPlace get nextStop => isPickedUp ? dropoff : pickup;

  String get statusLabel => switch (status) {
        'open' => tr('Waiting for a transporter'),
        'accepted' => tr('Transporter on the way to pickup'),
        'picked_up' => tr('On the way to you'),
        'delivered' => tr('Delivered'),
        'cancelled' => tr('Cancelled'),
        _ => status,
      };
}

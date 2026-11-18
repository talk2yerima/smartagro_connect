import '../core/constants/nigerian_states.dart';
import '../core/utils/geo.dart';
import 'entities/product_listing.dart';

/// State capitals, used as a listing's position when it has no exact
/// coordinates (most listings give only a state and town).
const stateCentres = <String, GeoPoint2>{
  'Abia': GeoPoint2(5.5250, 7.4922),
  'Adamawa': GeoPoint2(9.2035, 12.4954),
  'Akwa Ibom': GeoPoint2(5.0377, 7.9128),
  'Anambra': GeoPoint2(6.2104, 7.0741),
  'Bauchi': GeoPoint2(10.3158, 9.8442),
  'Bayelsa': GeoPoint2(4.9267, 6.2676),
  'Benue': GeoPoint2(7.7322, 8.5391),
  'Borno': GeoPoint2(11.8311, 13.1510),
  'Cross River': GeoPoint2(4.9517, 8.3220),
  'Delta': GeoPoint2(6.1985, 6.7296),
  'Ebonyi': GeoPoint2(6.3249, 8.1137),
  'Edo': GeoPoint2(6.3350, 5.6037),
  'Ekiti': GeoPoint2(7.6211, 5.2214),
  'Enugu': GeoPoint2(6.4584, 7.5464),
  'FCT — Abuja': GeoPoint2(9.0765, 7.3986),
  'Gombe': GeoPoint2(10.2897, 11.1673),
  'Imo': GeoPoint2(5.4840, 7.0351),
  'Jigawa': GeoPoint2(11.7562, 9.3388),
  'Kaduna': GeoPoint2(10.5222, 7.4383),
  'Kano': GeoPoint2(12.0022, 8.5920),
  'Katsina': GeoPoint2(12.9908, 7.6018),
  'Kebbi': GeoPoint2(12.4539, 4.1975),
  'Kogi': GeoPoint2(7.8023, 6.7333),
  'Kwara': GeoPoint2(8.4966, 4.5426),
  'Lagos': GeoPoint2(6.6018, 3.3515),
  'Nasarawa': GeoPoint2(8.4939, 8.5150),
  'Niger': GeoPoint2(9.6139, 6.5569),
  'Ogun': GeoPoint2(7.1475, 3.3619),
  'Ondo': GeoPoint2(7.2526, 5.1931),
  'Osun': GeoPoint2(7.7827, 4.5418),
  'Oyo': GeoPoint2(7.3775, 3.9470),
  'Plateau': GeoPoint2(9.8965, 8.8583),
  'Rivers': GeoPoint2(4.8156, 7.0498),
  'Sokoto': GeoPoint2(13.0059, 5.2476),
  'Taraba': GeoPoint2(8.8937, 11.3600),
  'Yobe': GeoPoint2(11.7470, 11.9608),
  'Zamfara': GeoPoint2(12.1628, 6.6614),
};

/// Where a listing is: its own coordinates, else its state's capital,
/// else null (unknown).
GeoPoint2? listingPoint(ProductListing p) {
  final own = GeoPoint2(p.lat, p.lng);
  if (own.isSet) return own;
  var c = stateCentres[p.state];
  if (c == null && p.state.toUpperCase().startsWith('FCT')) {
    c = stateCentres[kNigerianStates.firstWhere((s) => s.startsWith('FCT'))];
  }
  return c;
}

/// About how far a listing is from [me] by road, or null if unknown.
double? listingDistanceKm(ProductListing p, GeoPoint2? me) {
  final at = listingPoint(p);
  if (me == null || at == null) return null;
  return estimatedRoadKm(me, at);
}

enum ReadyFilter { any, readyNow, preOrder }

/// The marketplace filter sheet's choices.
class ListingFilter {
  const ListingFilter({
    this.minPrice,
    this.maxPrice,
    this.maxDistanceKm,
    this.verifiedOnly = false,
    this.ready = ReadyFilter.any,
    this.state,
    this.hideSoldOut = false,
  });

  /// Price per kg, in naira (null = no limit).
  final int? minPrice;
  final int? maxPrice;

  /// Only listings within this road distance (needs the person's position).
  final double? maxDistanceKm;
  final bool verifiedOnly;
  final ReadyFilter ready;
  final String? state;
  final bool hideSoldOut;

  static const none = ListingFilter();

  /// How many filters are on (for the badge on the filter button).
  int get activeCount => [
        minPrice != null || maxPrice != null,
        maxDistanceKm != null,
        verifiedOnly,
        ready != ReadyFilter.any,
        state != null,
        hideSoldOut,
      ].where((on) => on).length;

  bool matches(ProductListing p, {GeoPoint2? me}) {
    if (minPrice != null && p.priceNgn < minPrice!) return false;
    if (maxPrice != null && p.priceNgn > maxPrice!) return false;
    if (verifiedOnly && !p.verified) return false;
    if (state != null && p.state != state) return false;
    if (hideSoldOut && p.availability == ProductAvailability.soldOut) {
      return false;
    }
    switch (ready) {
      case ReadyFilter.any:
        break;
      case ReadyFilter.readyNow:
        if (!p.readyNow) return false;
      case ReadyFilter.preOrder:
        if (p.availability != ProductAvailability.preOrder) return false;
    }
    if (maxDistanceKm != null) {
      final km = listingDistanceKm(p, me);
      // Without the person's position the distance filter can't apply.
      if (me != null && (km == null || km > maxDistanceKm!)) return false;
    }
    return true;
  }

  ListingFilter copyWith({
    int? Function()? minPrice,
    int? Function()? maxPrice,
    double? Function()? maxDistanceKm,
    bool? verifiedOnly,
    ReadyFilter? ready,
    String? Function()? state,
    bool? hideSoldOut,
  }) =>
      ListingFilter(
        minPrice: minPrice == null ? this.minPrice : minPrice(),
        maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
        maxDistanceKm:
            maxDistanceKm == null ? this.maxDistanceKm : maxDistanceKm(),
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        ready: ready ?? this.ready,
        state: state == null ? this.state : state(),
        hideSoldOut: hideSoldOut ?? this.hideSoldOut,
      );
}

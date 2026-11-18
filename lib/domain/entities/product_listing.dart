import 'package:equatable/equatable.dart';

/// preOrder: still growing; buyers pay now and it is delivered at harvest.
enum ProductAvailability { inStock, limited, preOrder, soldOut }

/// Farmer listing shown in marketplace + search.
class ProductListing extends Equatable {
  const ProductListing({
    required this.id,
    required this.title,
    required this.description,
    required this.priceNgn,
    required this.quantityKg,
    required this.state,
    required this.city,
    required this.sellerId,
    required this.sellerName,
    required this.sellerRating,
    required this.verified,
    required this.availability,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    this.imageUrls = const [],
  });

  final String id;
  final String title;
  final String description;
  final int priceNgn;
  final int quantityKg;
  final String state;
  final String city;
  final String sellerId;
  final String sellerName;
  final double sellerRating;
  final bool verified;
  final ProductAvailability availability;
  final String imageUrl;
  final double lat;
  final double lng;

  /// Every photo of the listing, the cover ([imageUrl]) first. Older
  /// listings only have [imageUrl].
  final List<String> imageUrls;

  /// The photos to show (never empty when there is any photo).
  List<String> get photos {
    final all = <String>[
      if (imageUrl.isNotEmpty) imageUrl,
      for (final u in imageUrls)
        if (u.isNotEmpty && u != imageUrl) u,
    ];
    return all;
  }

  /// Ready to collect now (not still growing, not sold out).
  bool get readyNow =>
      availability == ProductAvailability.inStock ||
      availability == ProductAvailability.limited;

  @override
  List<Object?> get props => [id];
}

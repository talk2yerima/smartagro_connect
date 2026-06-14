import 'package:equatable/equatable.dart';

enum ProductAvailability { inStock, limited, soldOut }

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

  @override
  List<Object?> get props => [id];
}

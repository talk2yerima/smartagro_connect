import 'package:equatable/equatable.dart';

/// A paid order, created by the payments backend once Paystack confirms
/// the payment (`orders/{reference}`). Both the buyer and the seller see it.
class MarketOrder extends Equatable {
  const MarketOrder({
    required this.reference,
    required this.productId,
    required this.description,
    required this.amountKobo,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.createdAt,
    this.sellerShareKobo,
    this.platformFeeKobo,
    this.dispatchedAt,
    this.receivedAt,
    this.rating,
    this.review,
    this.quantityKg,
    this.shortfallKg = 0,
  });

  factory MarketOrder.fromMap(String id, Map<String, dynamic> m) {
    return MarketOrder(
      reference: (m['reference'] as String?) ?? id,
      productId: (m['productId'] as String?) ?? '',
      description: (m['description'] as String?) ?? 'Order',
      amountKobo: (m['amountKobo'] as num?)?.toInt() ?? 0,
      sellerShareKobo: (m['sellerShareKobo'] as num?)?.toInt(),
      platformFeeKobo: (m['platformFeeKobo'] as num?)?.toInt(),
      buyerId: (m['buyerId'] as String?) ?? '',
      sellerId: (m['sellerId'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'paid',
      createdAt: _date(m['createdAt']) ?? DateTime.now(),
      dispatchedAt: _date(m['dispatchedAt']),
      receivedAt: _date(m['receivedAt']),
      rating: (m['rating'] as num?)?.toInt(),
      review: m['review'] as String?,
      quantityKg: (m['quantityKg'] as num?)?.toInt(),
      shortfallKg: (m['shortfallKg'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _date(Object? v) => v is DateTime
      ? v
      : v is String
          ? DateTime.tryParse(v)
          : null;

  final String reference;
  final String productId;
  final String description;

  /// What the buyer paid, in kobo.
  final int amountKobo;

  /// What the seller receives after SmartAgro's fee (null on old orders
  /// made before payouts existed).
  final int? sellerShareKobo;
  final int? platformFeeKobo;
  final String buyerId;
  final String sellerId;

  /// 'paid' → 'dispatched' (seller) → 'received' (buyer).
  final String status;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? receivedAt;

  /// The buyer's 1-5 rating of the seller, once given.
  final int? rating;
  final String? review;

  /// How many kg were bought (null on orders from before partial buying).
  final int? quantityKg;

  /// Kilos the seller couldn't supply because another buyer paid for the
  /// last stock first. The two of them need to agree a refund or swap.
  final int shortfallKg;

  bool get isPaid => status == 'paid';
  bool get isDispatched => status == 'dispatched';
  bool get isReceived => status == 'received';

  @override
  List<Object?> get props => [reference, status, rating];
}

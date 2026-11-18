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
  });

  factory MarketOrder.fromMap(String id, Map<String, dynamic> m) {
    final created = m['createdAt'];
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
      createdAt: created is DateTime
          ? created
          : created is String
              ? DateTime.tryParse(created) ?? DateTime.now()
              : DateTime.now(),
    );
  }

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

  /// 'paid' for now; delivery confirmation will add more states.
  final String status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [reference, status];
}

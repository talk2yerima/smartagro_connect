import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/domain/entities/market_order.dart';

void main() {
  test('reads a paid order with the payout split', () {
    final o = MarketOrder.fromMap('SA-1', {
      'reference': 'SA-1',
      'productId': 'p1',
      'description': '50 kg of Fresh Tomato',
      'amountKobo': 5000000,
      'sellerShareKobo': 4750000,
      'platformFeeKobo': 250000,
      'buyerId': 'b1',
      'sellerId': 's1',
      'status': 'paid',
      'createdAt': DateTime(2026, 11, 18, 12),
    });
    expect(o.amountKobo, 5000000);
    expect(o.sellerShareKobo, 4750000);
    expect(o.platformFeeKobo, 250000);
    expect(o.createdAt, DateTime(2026, 11, 18, 12));
  });

  test('orders from before payouts have no seller share', () {
    final o = MarketOrder.fromMap('SA-2', const {
      'amountKobo': 100,
      'buyerId': 'b1',
      'sellerId': 's1',
    });
    expect(o.sellerShareKobo, isNull);
    expect(o.reference, 'SA-2');
    expect(o.status, 'paid');
    expect(o.description, 'Order');
  });

  test('reads delivery tracking and the buyer rating', () {
    final o = MarketOrder.fromMap('SA-3', {
      'amountKobo': 100,
      'buyerId': 'b1',
      'sellerId': 's1',
      'status': 'received',
      'dispatchedAt': DateTime(2026, 11, 18, 9),
      'receivedAt': DateTime(2026, 11, 19, 15),
      'rating': 4,
      'review': 'Fresh and on time',
    });
    expect(o.isReceived, isTrue);
    expect(o.isPaid, isFalse);
    expect(o.receivedAt, DateTime(2026, 11, 19, 15));
    expect(o.rating, 4);
    expect(o.review, 'Fresh and on time');
  });

  test('reads the quantity bought and any shortfall', () {
    final o = MarketOrder.fromMap('SA-4', const {
      'amountKobo': 100,
      'buyerId': 'b1',
      'sellerId': 's1',
      'quantityKg': 30,
      'shortfallKg': 10,
    });
    expect(o.quantityKg, 30);
    expect(o.shortfallKg, 10);
    expect(MarketOrder.fromMap('x', const {}).shortfallKg, 0);
  });
}

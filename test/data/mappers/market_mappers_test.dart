import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/data/mappers/market_mappers.dart';
import 'package:smartagro_connect/domain/entities/chat_models.dart';
import 'package:smartagro_connect/domain/entities/product_listing.dart';

void main() {
  // ── commodityFromMap ────────────────────────────────────────────────────────
  group('commodityFromMap', () {
    final map = {
      'id': 'c1',
      'name': 'Maize',
      'unit': 'kg',
      'priceNgn': 350,
      'changePct': 2.5,
      'category': 'Grains',
    };

    test('maps all fields correctly', () {
      final c = commodityFromMap(map);
      expect(c.id, 'c1');
      expect(c.name, 'Maize');
      expect(c.unit, 'kg');
      expect(c.priceNgn, 350);
      expect(c.changePct, 2.5);
      expect(c.category, 'Grains');
    });

    test('coerces num priceNgn to int', () {
      final c = commodityFromMap({...map, 'priceNgn': 350.9});
      expect(c.priceNgn, 350);
    });

    test('coerces int changePct to double', () {
      final c = commodityFromMap({...map, 'changePct': 3});
      expect(c.changePct, 3.0);
      expect(c.changePct, isA<double>());
    });

    test('equality uses id only', () {
      final a = commodityFromMap(map);
      final b = commodityFromMap({...map, 'name': 'Yellow Maize'});
      expect(a, equals(b));
    });
  });

  // ── productFromMap ──────────────────────────────────────────────────────────
  group('productFromMap', () {
    final base = {
      'id': 'p1',
      'title': 'Fresh Tomatoes',
      'description': 'Grade A tomatoes',
      'priceNgn': 1200,
      'quantityKg': 500,
      'state': 'Lagos',
      'city': 'Ikeja',
      'sellerId': 's1',
      'sellerName': 'Emeka Farms',
      'sellerRating': 4.7,
      'verified': true,
      'availability': 'in_stock',
      'imageUrl': 'https://example.com/tomato.jpg',
      'lat': 6.5244,
      'lng': 3.3792,
    };

    test('maps all fields correctly', () {
      final p = productFromMap(base);
      expect(p.id, 'p1');
      expect(p.title, 'Fresh Tomatoes');
      expect(p.priceNgn, 1200);
      expect(p.quantityKg, 500);
      expect(p.state, 'Lagos');
      expect(p.city, 'Ikeja');
      expect(p.sellerId, 's1');
      expect(p.sellerName, 'Emeka Farms');
      expect(p.sellerRating, 4.7);
      expect(p.verified, isTrue);
      expect(p.availability, ProductAvailability.inStock);
      expect(p.lat, closeTo(6.5244, 0.0001));
      expect(p.lng, closeTo(3.3792, 0.0001));
    });

    test('availability: limited maps correctly', () {
      final p = productFromMap({...base, 'availability': 'limited'});
      expect(p.availability, ProductAvailability.limited);
    });

    test('availability: sold_out maps correctly', () {
      final p = productFromMap({...base, 'availability': 'sold_out'});
      expect(p.availability, ProductAvailability.soldOut);
    });

    test('unknown availability defaults to inStock', () {
      final p = productFromMap({...base, 'availability': 'unknown_value'});
      expect(p.availability, ProductAvailability.inStock);
    });

    test('null availability defaults to inStock', () {
      final p = productFromMap({...base, 'availability': null});
      expect(p.availability, ProductAvailability.inStock);
    });
  });

  // ── buyerFromMap ────────────────────────────────────────────────────────────
  group('buyerFromMap', () {
    final map = {
      'id': 'b1',
      'name': 'Ade Wholesalers',
      'type': 'Wholesaler',
      'state': 'Ogun',
      'distanceKm': 12,
      'rating': 4.2,
      'verified': false,
    };

    test('maps all fields correctly', () {
      final b = buyerFromMap(map);
      expect(b.id, 'b1');
      expect(b.name, 'Ade Wholesalers');
      expect(b.type, 'Wholesaler');
      expect(b.state, 'Ogun');
      expect(b.distanceKm, 12);
      expect(b.rating, 4.2);
      expect(b.verified, isFalse);
    });

    test('coerces num distanceKm to int', () {
      final b = buyerFromMap({...map, 'distanceKm': 12.9});
      expect(b.distanceKm, 12);
    });
  });

  // ── chatThreadFromMap ───────────────────────────────────────────────────────
  group('chatThreadFromMap', () {
    final map = {
      'id': 't1',
      'peerId': 'u2',
      'peerName': 'Bola Farms',
      'peerRole': 'farmer',
      'lastMessage': 'How much per kg?',
      'updatedAt': '2024-06-10T09:00:00.000Z',
      'unread': 3,
    };

    test('maps all fields correctly', () {
      final t = chatThreadFromMap(map);
      expect(t.id, 't1');
      expect(t.peerId, 'u2');
      expect(t.peerName, 'Bola Farms');
      expect(t.peerRole, 'farmer');
      expect(t.lastMessage, 'How much per kg?');
      expect(t.unread, 3);
      expect(t.updatedAt, DateTime.parse('2024-06-10T09:00:00.000Z'));
    });
  });

  // ── chatMessageFromMap ──────────────────────────────────────────────────────
  group('chatMessageFromMap', () {
    final base = {
      'id': 'm1',
      'threadId': 't1',
      'fromMe': true,
      'text': 'Hello',
      'sentAt': '2024-06-10T09:05:00.000Z',
      'kind': 'text',
    };

    test('maps text message', () {
      final m = chatMessageFromMap(base);
      expect(m.id, 'm1');
      expect(m.fromMe, isTrue);
      expect(m.text, 'Hello');
      expect(m.kind, ChatMessageKind.text);
    });

    test('maps image kind', () {
      final m = chatMessageFromMap({...base, 'kind': 'image'});
      expect(m.kind, ChatMessageKind.image);
    });

    test('maps voice kind', () {
      final m = chatMessageFromMap({...base, 'kind': 'voice'});
      expect(m.kind, ChatMessageKind.voice);
    });

    test('unknown kind defaults to text', () {
      final m = chatMessageFromMap({...base, 'kind': null});
      expect(m.kind, ChatMessageKind.text);
    });
  });
}

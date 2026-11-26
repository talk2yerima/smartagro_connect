import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/utils/geo.dart';
import 'package:smartagro_connect/data/mappers/market_mappers.dart';
import 'package:smartagro_connect/domain/entities/farm_profile.dart';
import 'package:smartagro_connect/domain/entities/product_listing.dart';
import 'package:smartagro_connect/domain/farmer_directory.dart';
import 'package:smartagro_connect/domain/listing_filter.dart';

ProductListing listing(
  String id, {
  String seller = 's1',
  String title = 'Fresh Tomato',
  int price = 500,
  String state = 'Yobe',
  bool verified = false,
  String availability = 'in_stock',
  double rating = 4,
}) =>
    productFromMap({
      'id': id,
      'title': title,
      'priceNgn': price,
      'quantityKg': 100,
      'state': state,
      'city': '',
      'sellerId': seller,
      'sellerName': 'Seller $seller',
      'sellerRating': rating,
      'verified': verified,
      'availability': availability,
      'imageUrl': 'https://x/$id.jpg',
    });

void main() {
  group('listing photos and pre-order', () {
    test('cover first, extras after, no duplicates', () {
      final p = productFromMap({
        'id': 'a',
        'imageUrl': 'https://x/1.jpg',
        'imageUrls': ['https://x/1.jpg', 'https://x/2.jpg', '', 3],
      });
      expect(p.photos, ['https://x/1.jpg', 'https://x/2.jpg']);
      expect(listing('b').photos, ['https://x/b.jpg']);
    });

    test('pre-order is read back as pre-order, not in stock', () {
      final p = listing('c', availability: 'pre_order');
      expect(p.availability, ProductAvailability.preOrder);
      expect(p.readyNow, isFalse);
      expect(listing('d', availability: 'limited').readyNow, isTrue);
    });
  });

  group('marketplace filter', () {
    final items = [
      listing('cheap', price: 200),
      listing('dear', price: 2000, verified: true),
      listing('later', availability: 'pre_order', state: 'Kano'),
      listing('gone', availability: 'sold_out', state: 'Lagos'),
    ];
    List<String> ids(ListingFilter f, {GeoPoint2? me}) =>
        items.where((p) => f.matches(p, me: me)).map((p) => p.id).toList();

    test('no filter shows everything', () {
      expect(ids(ListingFilter.none), hasLength(4));
      expect(ListingFilter.none.activeCount, 0);
    });

    test('price range, verified, state and availability', () {
      expect(
          ids(const ListingFilter(maxPrice: 600)), ['cheap', 'later', 'gone']);
      expect(ids(const ListingFilter(minPrice: 1000)), ['dear']);
      expect(ids(const ListingFilter(verifiedOnly: true)), ['dear']);
      expect(ids(const ListingFilter(state: 'Kano')), ['later']);
      expect(ids(const ListingFilter(ready: ReadyFilter.preOrder)), ['later']);
      expect(ids(const ListingFilter(ready: ReadyFilter.readyNow)),
          ['cheap', 'dear']);
      expect(
          ids(const ListingFilter(hideSoldOut: true)), isNot(contains('gone')));
      expect(
          const ListingFilter(minPrice: 1, verifiedOnly: true, state: 'Yobe')
              .activeCount,
          3);
    });

    test('distance uses the state capital when a listing has no position', () {
      const damaturu = GeoPoint2(11.7470, 11.9608); // Yobe capital
      final near = ids(const ListingFilter(maxDistanceKm: 50), me: damaturu);
      expect(near, ['cheap', 'dear']); // Yobe, not Kano or Lagos
      final wide = ids(const ListingFilter(maxDistanceKm: 500), me: damaturu);
      expect(wide, containsAll(['cheap', 'dear', 'later']));
      expect(wide, isNot(contains('gone'))); // Lagos is ~1,300 km away
      // Without the person's position the distance filter can't apply.
      expect(ids(const ListingFilter(maxDistanceKm: 50)), hasLength(4));
      expect(stateCentres.length, 37);
    });

    test('copyWith can clear a limit', () {
      const f = ListingFilter(maxPrice: 900, state: 'Yobe');
      final cleared = f.copyWith(maxPrice: () => null, state: () => null);
      expect(cleared.maxPrice, isNull);
      expect(cleared.state, isNull);
      expect(f.copyWith(verifiedOnly: true).maxPrice, 900);
    });
  });

  group('farmer profile', () {
    test('reads the farm details and the star breakdown', () {
      final p = FarmProfile.fromMap('s1', {
        'name': 'Amina Bello',
        'about': '  Mixed farm in Gashua ',
        'openingHours': 'Mon – Sat, 7 AM – 6 PM',
        'farmCategories': ['Poultry', 'Grains', 4],
        'galleryUrls': ['https://x/g1.jpg'],
        'coverUrl': '',
        'rating': 4.3,
        'ratingCounts': {'5': 6, '4': 2, '1': 2, '9': 4},
      });
      expect(p.about, 'Mixed farm in Gashua');
      expect(p.categories, ['Poultry', 'Grains']);
      expect(p.coverUrl, isNull);
      expect(p.ratingCount, 10);
      expect(p.shareOf(5), closeTo(0.6, 1e-9));
      expect(p.shareOf(3), 0);
      expect(p.hasFarmDetails, isTrue);
      expect(FarmProfile.fromMap('x', const {}).hasFarmDetails, isFalse);
      expect(FarmProfile.fromMap('x', const {}).name, 'Farmer');
    });

    test('similar farmers: same state, same produce first, not themselves', () {
      final all = [
        listing('m1', seller: 'me', title: 'Fresh Tomato'),
        listing('o1', seller: 'onion', title: 'Red Onion', rating: 5),
        listing('t1', seller: 'tomato', title: 'Roma Tomato', rating: 3),
        listing('k1', seller: 'kano', title: 'Tomato', state: 'Kano'),
      ];
      final similar = similarFarmers('me', all);
      expect(similar.map((f) => f.id), ['tomato', 'onion']);
      expect(similar.first.products, 1);
      expect(similarFarmers('nobody', all), isEmpty);
    });
  });
}

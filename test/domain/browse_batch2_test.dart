import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/data/mappers/market_mappers.dart';
import 'package:smartagro_connect/domain/entities/farm_profile.dart';
import 'package:smartagro_connect/domain/entities/market_order.dart';
import 'package:smartagro_connect/domain/entities/product_listing.dart';
import 'package:smartagro_connect/domain/farmer_directory.dart';

ProductListing p(
  String id,
  String seller, {
  String title = 'Tomato',
  int price = 500,
  String state = 'Yobe',
  double rating = 4,
  bool verified = false,
  String availability = 'in_stock',
  String image = 'https://x/a.jpg',
}) =>
    productFromMap({
      'id': id,
      'title': title,
      'priceNgn': price,
      'quantityKg': 50,
      'state': state,
      'city': '',
      'sellerId': seller,
      'sellerName': 'Farmer $seller',
      'sellerRating': rating,
      'verified': verified,
      'availability': availability,
      'imageUrl': image,
    });

void main() {
  test('produce key compares like with like', () {
    expect(produceKey('Fresh Roma Tomatoes'), 'tomato');
    expect(produceKey('Tomato'), 'tomato');
    expect(produceKey('White Maize'), 'maize');
    expect(produceKey('Yam Tubers'), 'tuber');
  });

  test('best price goes to the cheapest of at least two on sale now', () {
    final all = [
      p('a', 's1', title: 'Fresh Tomatoes', price: 600),
      p('b', 's2', title: 'Tomato', price: 450),
      p('c', 's3', title: 'Tomato', price: 300, availability: 'sold_out'),
      p('d', 's4', title: 'Maize', price: 100),
    ];
    expect(bestPriceIds(all), {'b'});
  });

  test('top farmers favour rating, verification and range', () {
    final all = [
      p('a', 'low', rating: 3),
      p('b', 'high', rating: 4.8, verified: true),
      p('c', 'high', title: 'Onion', rating: 4.8, verified: true),
      p('d', 'mid', rating: 4.5),
    ];
    final top = topFarmers(all);
    expect(top.map((f) => f.id), ['high', 'mid', 'low']);
    expect(top.first.products, 2);
    expect(top.first.verified, isTrue);
  });

  test('recommended: saved first, then my state, never me', () {
    final all = [
      p('a', 'kano', state: 'Kano', rating: 5, verified: true),
      p('b', 'yobe', state: 'Yobe', rating: 4),
      p('c', 'saved', state: 'Lagos', rating: 3),
      p('d', 'me', state: 'Yobe', rating: 5),
    ];
    final rec = recommendedFarmers(all,
        myId: 'me', myLocation: 'Gashua, Yobe', saved: {'saved'});
    expect(rec.map((f) => f.id), ['saved', 'yobe', 'kano']);
  });

  test('trending skips sold out; states counted most first', () {
    final all = [
      p('a', 's1', availability: 'sold_out'),
      p('b', 's2', state: 'Kano'),
      p('c', 's3', state: 'Kano'),
      p('d', 's4', state: 'Yobe', image: ''),
    ];
    expect(trendingProducts(all).map((x) => x.id), isNot(contains('a')));
    final states = listingsByState(all);
    expect(states.first.state, 'Kano');
    expect(states.first.count, 2);
    expect(states.map((s) => s.state), isNot(contains(''))); // sold out skipped
  });

  test('review tags: read, filtered, and summarised', () {
    final r1 = SellerReview.fromMap('r1', {
      'rating': 5,
      'tags': ['Fresh produce', 'Fast delivery', 'nonsense'],
    });
    final r2 = SellerReview.fromMap('r2', {
      'rating': 4,
      'tags': ['Fresh produce'],
    });
    expect(r1.tags, ['Fresh produce', 'Fast delivery']);
    final top = topReviewTags([r1, r2]);
    expect(top.first.tag, 'Fresh produce');
    expect(top.first.count, 2);
    final order = MarketOrder.fromMap('SA-1', const {
      'rating': 4,
      'reviewTags': ['Well packed'],
    });
    expect(order.reviewTags, ['Well packed']);
  });
}

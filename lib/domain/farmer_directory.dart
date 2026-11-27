import 'dart:math' as math;

import 'entities/product_listing.dart';

/// A farmer as seen through their listings (for Explore, Home and
/// "similar farmers").
typedef FarmerSummary = ({
  String id,
  String name,
  double rating,
  bool verified,
  String imageUrl,
  String state,
  String place,
  int products,
});

Map<String, List<ProductListing>> _bySeller(Iterable<ProductListing> all) {
  final map = <String, List<ProductListing>>{};
  for (final p in all) {
    if (p.sellerId.isEmpty) continue;
    map.putIfAbsent(p.sellerId, () => []).add(p);
  }
  return map;
}

FarmerSummary _summary(String id, List<ProductListing> ps) {
  final first = ps.first;
  return (
    id: id,
    name: first.sellerName.isEmpty ? 'Farmer' : first.sellerName,
    rating: ps.map((p) => p.sellerRating).reduce(math.max),
    verified: ps.any((p) => p.verified),
    imageUrl: ps
        .map((p) => p.imageUrl)
        .firstWhere((u) => u.isNotEmpty, orElse: () => ''),
    state: first.state,
    place: first.city.isEmpty ? first.state : '${first.city}, ${first.state}',
    products: ps.length,
  );
}

/// Every farmer with a listing.
List<FarmerSummary> farmersFrom(Iterable<ProductListing> all) => [
      for (final e in _bySeller(all).entries) _summary(e.key, e.value),
    ];

/// Score for "top farmers": rating first, then how much they offer, with a
/// little extra for verified farms.
double _topScore(FarmerSummary f) =>
    f.rating + (f.verified ? 0.5 : 0) + math.log(f.products + 1) * 0.3;

/// Best-rated, verified, well-stocked farmers first.
List<FarmerSummary> topFarmers(Iterable<ProductListing> all, {int max = 10}) {
  final list = farmersFrom(all)
    ..sort((a, b) => _topScore(b).compareTo(_topScore(a)));
  return list.take(max).toList();
}

/// Farmers for this person's Home: saved ones first, then those in their
/// state, then the best rated. Never themselves.
List<FarmerSummary> recommendedFarmers(
  Iterable<ProductListing> all, {
  required String? myId,
  String? myLocation,
  Set<String> saved = const {},
  int max = 10,
}) {
  final loc = (myLocation ?? '').toLowerCase();
  double score(FarmerSummary f) =>
      _topScore(f) +
      (saved.contains(f.id) ? 10 : 0) +
      (loc.isNotEmpty &&
              f.state.isNotEmpty &&
              loc.contains(f.state.toLowerCase())
          ? 3
          : 0);
  final list = farmersFrom(all).where((f) => f.id != myId).toList()
    ..sort((a, b) => score(b).compareTo(score(a)));
  return list.take(max).toList();
}

/// Other sellers in the same state(s) as [sellerId], those selling the
/// same kind of produce first, then the best rated.
List<FarmerSummary> similarFarmers(String sellerId, List<ProductListing> all,
    {int max = 8}) {
  final mine = all.where((p) => p.sellerId == sellerId).toList();
  if (mine.isEmpty) return const [];
  final states = {for (final p in mine) p.state};
  final words = {for (final p in mine) ..._words(p.title)};
  final others = _bySeller(
      all.where((p) => p.sellerId != sellerId && states.contains(p.state)));
  int overlap(List<ProductListing> ps) =>
      ps.where((p) => _words(p.title).any(words.contains)).length;
  final ids = others.keys.toList()
    ..sort((a, b) {
      final o = overlap(others[b]!).compareTo(overlap(others[a]!));
      if (o != 0) return o;
      return others[b]!
          .first
          .sellerRating
          .compareTo(others[a]!.first.sellerRating);
    });
  return [for (final id in ids.take(max)) _summary(id, others[id]!)];
}

Set<String> _words(String title) => title
    .toLowerCase()
    .split(RegExp(r'[^a-z]+'))
    .where((w) => w.length >= 4)
    .toSet();

/// The produce a listing is (its main word: "Fresh Roma Tomatoes" →
/// "tomato"), for comparing prices of like with like.
String produceKey(String title) {
  const skip = {
    'fresh',
    'dried',
    'dry',
    'local',
    'organic',
    'premium',
    'quality',
    'grade',
    'bags',
    'sack',
    'white',
    'yellow',
    'brown',
    'large',
    'small',
  };
  final words = title
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((w) => w.length >= 3 && !skip.contains(w))
      .toList();
  if (words.isEmpty) return title.toLowerCase().trim();
  var w = words.last;
  if (w.endsWith('oes')) w = w.substring(0, w.length - 2);
  if (w.endsWith('s') && !w.endsWith('ss')) w = w.substring(0, w.length - 1);
  return w;
}

/// Listings that are the cheapest per kg among at least two of the same
/// produce on sale now ("Best price" badge).
Set<String> bestPriceIds(Iterable<ProductListing> all) {
  final groups = <String, List<ProductListing>>{};
  for (final p in all) {
    if (!p.readyNow || p.priceNgn <= 0) continue;
    groups.putIfAbsent(produceKey(p.title), () => []).add(p);
  }
  return {
    for (final g in groups.values)
      if (g.length >= 2)
        g.reduce((a, b) => a.priceNgn <= b.priceNgn ? a : b).id,
  };
}

/// Listings worth showing first on Explore: on sale now, from good and
/// verified sellers, with a photo.
List<ProductListing> trendingProducts(Iterable<ProductListing> all,
    {int max = 12}) {
  double score(ProductListing p) =>
      p.sellerRating +
      (p.verified ? 0.6 : 0) +
      (p.imageUrl.isNotEmpty ? 0.4 : 0) +
      (p.availability == ProductAvailability.limited ? 0.2 : 0);
  final list = all
      .where((p) => p.availability != ProductAvailability.soldOut)
      .toList()
    ..sort((a, b) => score(b).compareTo(score(a)));
  return list.take(max).toList();
}

/// How many listings each state has, most first.
List<({String state, int count})> listingsByState(
    Iterable<ProductListing> all) {
  final counts = <String, int>{};
  for (final p in all) {
    if (p.state.isEmpty || p.availability == ProductAvailability.soldOut) {
      continue;
    }
    counts[p.state] = (counts[p.state] ?? 0) + 1;
  }
  final list = [
    for (final e in counts.entries) (state: e.key, count: e.value),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

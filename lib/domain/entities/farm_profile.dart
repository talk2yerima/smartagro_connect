/// What a farmer shows buyers on their public profile (stored on
/// users/{uid}; the rating totals are written only by the backend).
class FarmProfile {
  const FarmProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.location,
    this.verified = false,
    this.rating = 0,
    this.ratingCount = 0,
    this.ratingCounts = const {},
    this.about = '',
    this.openingHours = '',
    this.categories = const [],
    this.coverUrl,
    this.galleryUrls = const [],
    this.memberSince,
  });

  factory FarmProfile.fromMap(String id, Map<String, dynamic> m) {
    List<String> strings(Object? v) =>
        v is List ? v.whereType<String>().toList() : const [];
    final counts = <int, int>{};
    final raw = m['ratingCounts'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final star = int.tryParse('$k');
        if (star != null && star >= 1 && star <= 5 && v is num) {
          counts[star] = v.toInt();
        }
      });
    }
    final created = m['createdAt'];
    final cover = m['coverUrl'] as String?;
    return FarmProfile(
      id: id,
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? (m['name'] as String).trim()
          : 'Farmer',
      avatarUrl: m['avatarUrl'] as String?,
      location: m['location'] as String?,
      verified: m['verified'] == true,
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (m['ratingCount'] as num?)?.toInt() ??
          counts.values.fold<int>(0, (a, b) => a + b),
      ratingCounts: counts,
      about: (m['about'] as String?)?.trim() ?? '',
      openingHours: (m['openingHours'] as String?)?.trim() ?? '',
      categories: strings(m['farmCategories']),
      coverUrl: cover == null || cover.isEmpty ? null : cover,
      galleryUrls: strings(m['galleryUrls']),
      memberSince: created is DateTime
          ? created
          : created is String
              ? DateTime.tryParse(created)
              : null,
    );
  }

  final String id;
  final String name;
  final String? avatarUrl;
  final String? location;
  final bool verified;
  final double rating;
  final int ratingCount;

  /// How many 1★…5★ ratings (for the reviews breakdown).
  final Map<int, int> ratingCounts;
  final String about;
  final String openingHours;

  /// What the farm produces, from [farmCategoryOptions].
  final List<String> categories;
  final String? coverUrl;
  final List<String> galleryUrls;
  final DateTime? memberSince;

  /// Share of ratings with [star] stars, 0..1 (for the breakdown bars).
  double shareOf(int star) {
    final total = ratingCounts.values.fold<int>(0, (a, b) => a + b);
    return total == 0 ? 0 : (ratingCounts[star] ?? 0) / total;
  }

  bool get hasFarmDetails =>
      about.isNotEmpty ||
      openingHours.isNotEmpty ||
      categories.isNotEmpty ||
      galleryUrls.isNotEmpty;
}

/// What a farm can say it produces.
const farmCategoryOptions = [
  'Grains',
  'Vegetables',
  'Fruits',
  'Tubers',
  'Legumes',
  'Poultry',
  'Livestock',
  'Fish',
  'Dairy',
  'Oilseeds',
];

/// Quick tags a buyer can add to a rating (the same list is enforced by
/// firestore.rules and the ratings backend).
const reviewTagOptions = [
  'Fresh produce',
  'Well packed',
  'Fast delivery',
  'As described',
  'Fair price',
  'Friendly seller',
  'Late delivery',
  'Poor quality',
  'Short weight',
];

/// Tags that count against a seller (shown in a different colour).
const negativeReviewTags = {'Late delivery', 'Poor quality', 'Short weight'};

/// Most gallery photos a farm profile keeps.
const maxGalleryPhotos = 6;

/// A buyer's published review of a seller (reviews/{orderRef}).
class SellerReview {
  const SellerReview({
    required this.id,
    required this.rating,
    required this.buyerName,
    required this.createdAt,
    this.review,
    this.product = '',
    this.tags = const [],
  });

  factory SellerReview.fromMap(String id, Map<String, dynamic> m) =>
      SellerReview(
        id: id,
        rating: ((m['rating'] as num?)?.toInt() ?? 0).clamp(1, 5),
        buyerName: (m['buyerName'] as String?) ?? 'Buyer',
        review: m['review'] as String?,
        product: (m['product'] as String?) ?? '',
        tags: (m['tags'] is List)
            ? (m['tags'] as List)
                .whereType<String>()
                .where(reviewTagOptions.contains)
                .toList()
            : const [],
        createdAt: m['createdAt'] is DateTime
            ? m['createdAt'] as DateTime
            : DateTime.now(),
      );

  final String id;
  final int rating;
  final String buyerName;
  final String? review;
  final String product;
  final DateTime createdAt;
  final List<String> tags;
}

/// The tags buyers chose most often, most first (for "Buyers say").
List<({String tag, int count})> topReviewTags(List<SellerReview> reviews,
    {int max = 4}) {
  final counts = <String, int>{};
  for (final r in reviews) {
    for (final t in r.tags) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final list = [for (final e in counts.entries) (tag: e.key, count: e.value)]
    ..sort((a, b) => b.count.compareTo(a.count));
  return list.take(max).toList();
}

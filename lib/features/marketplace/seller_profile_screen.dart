import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/farm_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/farm_profile.dart';
import '../../domain/entities/product_listing.dart';
import '../../domain/farmer_directory.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/produce_image.dart';
import '../orders/orders_screen.dart' show ReviewTagChips;

/// A farmer's public page: cover photo, About (story, what they grow,
/// opening hours, farm photos), Products, and Reviews with the star
/// breakdown, plus similar farmers nearby.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = ref.watch(productsProvider).valueOrNull ?? const [];
    final listings = all.where((p) => p.sellerId == sellerId).toList();
    final first = listings.isEmpty ? null : listings.first;
    final profile = ref.watch(farmProfileProvider(sellerId)).valueOrNull ??
        FarmProfile(
          id: sellerId,
          name: first?.sellerName ?? 'Farmer',
          rating: first?.sellerRating ?? 0,
          verified: first?.verified ?? false,
          location: first == null ? null : '${first.city}, ${first.state}',
        );
    final myId = ref.watch(authSessionProvider.select((u) => u?.id));
    final isMe = myId == sellerId;
    if (!isMe) {
      // For "Recently viewed farmers" on Home.
      Future.microtask(
          () => ref.read(recentFarmersProvider.notifier).viewed(sellerId));
    }
    final saved = ref.watch(favouriteFarmersProvider).contains(sellerId);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bg(isDark),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              backgroundColor: AppColors.deepGreen,
              foregroundColor: Colors.white,
              title: Text(profile.name),
              actions: [
                if (isMe)
                  IconButton(
                    tooltip: 'Edit farm profile',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push('/profile/farm'),
                  )
                else
                  IconButton(
                    tooltip: saved ? 'Remove from saved' : 'Save farmer',
                    icon: Icon(saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded),
                    color: saved ? const Color(0xFFFF6B6B) : Colors.white,
                    onPressed: () => ref
                        .read(favouriteFarmersProvider.notifier)
                        .toggle(sellerId),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _Header(profile: profile),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppColors.card(isDark),
                  child: TabBar(
                    labelColor:
                        isDark ? AppColors.lightGreen : AppColors.deepGreen,
                    indicatorColor:
                        isDark ? AppColors.lightGreen : AppColors.deepGreen,
                    tabs: [
                      const Tab(text: 'About'),
                      Tab(text: 'Products (${listings.length})'),
                      Tab(
                          text: profile.ratingCount > 0
                              ? 'Reviews (${profile.ratingCount})'
                              : 'Reviews'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AboutTab(profile: profile, isMe: isMe),
              _ProductsTab(sellerId: sellerId, listings: listings, all: all),
              _ReviewsTab(profile: profile),
            ],
          ),
        ),
        bottomNavigationBar: isMe
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: Text('Message ${profile.name.split(' ').first}'),
                    onPressed: myId == null
                        ? null
                        : () {
                            final ids = [myId, sellerId]..sort();
                            context.push('/chat/${ids.join('_')}'
                                '?name=${Uri.encodeComponent(profile.name)}'
                                '&peerId=$sellerId');
                          },
                  ),
                ),
              ),
      ),
    );
  }
}

/// Cover photo with the farmer's photo, name, rating and place over it.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final FarmProfile profile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (profile.coverUrl != null)
          ProduceImage(url: profile.coverUrl!, fit: BoxFit.cover)
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.deepGreen, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        // Keeps the white text readable on any photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0xCC000000)],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: AppAvatar(
                  name: profile.name,
                  imageUrl: profile.avatarUrl,
                  color: AppColors.emerald,
                  radius: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (profile.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF64B5F6), size: 20),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        _HeaderFact(
                          Icons.star_rounded,
                          profile.ratingCount == 0
                              ? 'New seller'
                              : '${profile.rating.toStringAsFixed(1)} '
                                  '(${profile.ratingCount})',
                          color: AppColors.golden,
                        ),
                        if ((profile.location ?? '').isNotEmpty)
                          _HeaderFact(Icons.place_outlined, profile.location!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact(this.icon, this.text, {this.color = Colors.white});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      );
}

TextStyle _sectionStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .titleSmall!
    .copyWith(fontWeight: FontWeight.w700);

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile, required this.isMe});

  final FarmProfile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    if (!profile.hasFarmDetails) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          EmptyState(
            icon: Icons.agriculture_outlined,
            title: isMe ? 'Tell buyers about your farm' : 'No farm details yet',
            subtitle: isMe
                ? 'Add your story, what you grow, your hours and photos. '
                    'Buyers trust farms they can see.'
                : 'This farmer has not described their farm yet. See their '
                    'products, or send them a message.',
            actionLabel: isMe ? 'Set up farm profile' : null,
            onAction: isMe ? () => context.push('/profile/farm') : null,
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (profile.about.isNotEmpty) ...[
          Text('About ${profile.name.split(' ').first}',
              style: _sectionStyle(context)),
          const SizedBox(height: 6),
          Text(profile.about, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 20),
        ],
        if (profile.categories.isNotEmpty) ...[
          Text('What we produce', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in profile.categories)
                Chip(
                  avatar: Icon(categoryIcon(c), size: 18),
                  label: Text(c),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (profile.openingHours.isNotEmpty) ...[
          Text('Opening hours', style: _sectionStyle(context)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.emerald),
              const SizedBox(width: 8),
              Expanded(child: Text(profile.openingHours)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (profile.galleryUrls.isNotEmpty) ...[
          Text('Farm gallery', style: _sectionStyle(context)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (var i = 0; i < profile.galleryUrls.length; i++)
                GestureDetector(
                  onTap: () => showPhotoViewer(context, profile.galleryUrls, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ProduceImage(url: profile.galleryUrls[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (profile.memberSince != null)
          Text(
              'On SmartAgro since '
              '${DateFormat('MMMM yyyy').format(profile.memberSince!)}',
              style: TextStyle(fontSize: 12, color: sub)),
      ],
    );
  }
}

IconData categoryIcon(String c) => switch (c) {
      'Grains' => Icons.grass_rounded,
      'Vegetables' => Icons.eco_rounded,
      'Fruits' => Icons.apple_rounded,
      'Tubers' => Icons.spa_rounded,
      'Legumes' => Icons.grain_rounded,
      'Poultry' => Icons.egg_alt_rounded,
      'Livestock' => Icons.pets_rounded,
      'Fish' => Icons.set_meal_rounded,
      'Dairy' => Icons.water_drop_rounded,
      'Oilseeds' => Icons.opacity_rounded,
      _ => Icons.agriculture_rounded,
    };

/// Full-screen photos: swipe between them, pinch to zoom.
void showPhotoViewer(BuildContext context, List<String> urls, int start) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: start),
        itemCount: urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(child: ProduceImage(url: urls[i], fit: BoxFit.contain)),
        ),
      ),
    ),
  ));
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab(
      {required this.sellerId, required this.listings, required this.all});

  final String sellerId;
  final List<ProductListing> listings;
  final List<ProductListing> all;

  @override
  Widget build(BuildContext context) {
    final similar = similarFarmers(sellerId, all);
    return CustomScrollView(
      slivers: [
        if (listings.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.storefront_rounded,
                title: 'No products right now',
                subtitle: 'Check back soon, or message the farmer.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => ProductTile(product: listings[i]),
                childCount: listings.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
            ),
          ),
        if (similar.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Similar farmers near you',
                  style: _sectionStyle(context)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => FarmerCard(farmer: similar[i]),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class FarmerCard extends StatelessWidget {
  const FarmerCard({super.key, required this.farmer});

  final FarmerSummary farmer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 150,
      child: Material(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/seller/${farmer.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 100,
                width: double.infinity,
                child: farmer.imageUrl.isEmpty
                    ? Container(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        child: const Icon(Icons.agriculture_rounded,
                            color: AppColors.emerald))
                    : ProduceImage(url: farmer.imageUrl),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(farmer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (farmer.verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Icon(Icons.verified_rounded,
                                size: 14, color: AppColors.infoBlue),
                          ),
                      ],
                    ),
                    Text(
                      '★ ${farmer.rating > 0 ? farmer.rating.toStringAsFixed(1) : 'New'}'
                      ' · ${farmer.products} product${farmer.products == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(farmer.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.subText(isDark))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A product in a grid: photo with price over it.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, this.bestPrice = false});

  final ProductListing product;

  /// Cheapest of its kind on sale now: shows a "Best price" badge.
  final bool bestPrice;

  @override
  Widget build(BuildContext context) {
    final soldOut = product.availability == ProductAvailability.soldOut;
    final preOrder = product.availability == ProductAvailability.preOrder;
    final (badge, badgeColor) = soldOut
        ? ('Sold out', AppColors.errorRed)
        : bestPrice
            ? ('Best price', AppColors.warningOrange)
            : preOrder
                ? ('Pre-order', AppColors.infoBlue)
                : (null, AppColors.gray);
    return GestureDetector(
      onTap: () => context.push('/marketplace/product/${product.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product.imageUrl.isNotEmpty)
              ProduceImage(url: product.imageUrl)
            else
              Container(
                color: AppColors.emerald,
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white70, size: 32),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('${formatNgn(product.priceNgn)} / kg',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(
                      '${NumberFormat.decimalPattern().format(product.quantityKg)} kg available',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab({required this.profile});

  final FarmProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(sellerReviewsProvider(profile.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = AppColors.subText(isDark);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border_(isDark)),
          ),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                      profile.ratingCount == 0
                          ? '–'
                          : profile.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800)),
                  _Stars(rating: profile.rating.round()),
                  const SizedBox(height: 4),
                  Text(
                      '${profile.ratingCount} rating'
                      '${profile.ratingCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: sub)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 14,
                                child: Text('$star',
                                    style: const TextStyle(fontSize: 12))),
                            const Icon(Icons.star_rounded,
                                size: 12, color: AppColors.golden),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: profile.shareOf(star),
                                  minHeight: 7,
                                  color: AppColors.golden,
                                  backgroundColor: AppColors.surface(isDark),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              child: Text('${profile.ratingCounts[star] ?? 0}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: sub)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...reviews.when(
          loading: () => [const Center(child: CircularProgressIndicator())],
          error: (_, __) => [
            Text('Reviews could not be loaded.', style: TextStyle(color: sub))
          ],
          data: (list) => list.isEmpty
              ? [
                  const EmptyState(
                    icon: Icons.reviews_outlined,
                    title: 'No reviews yet',
                    subtitle: 'Buyers can rate a farmer after their order '
                        'arrives.',
                  ),
                ]
              : [
                  if (topReviewTags(list).isNotEmpty) ...[
                    Text('Buyers say', style: _sectionStyle(context)),
                    const SizedBox(height: 8),
                    ReviewTagChips(
                      tags: [for (final t in topReviewTags(list)) t.tag],
                      counts: {
                        for (final t in topReviewTags(list)) t.tag: t.count
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  for (final r in list) ...[
                    _ReviewTile(review: r),
                    const Divider(height: 24),
                  ],
                ],
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: AppColors.golden),
        ],
      );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final SellerReview review;

  @override
  Widget build(BuildContext context) {
    final sub =
        AppColors.subText(Theme.of(context).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(
                name: review.buyerName, color: AppColors.emerald, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.buyerName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(DateFormat('d MMM yyyy').format(review.createdAt),
                      style: TextStyle(fontSize: 11, color: sub)),
                ],
              ),
            ),
            _Stars(rating: review.rating, size: 14),
          ],
        ),
        if ((review.review ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(review.review!),
        ],
        if (review.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReviewTagChips(tags: review.tags),
        ],
        if (review.product.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Bought: ${review.product}',
              style: TextStyle(fontSize: 12, color: sub)),
        ],
      ],
    );
  }
}

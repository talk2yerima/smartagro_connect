import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/haulage_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/entities/nearby_buyer.dart';
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/connectivity_banner.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/produce_image.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/sparkline_chart.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import 'farmers_for_you.dart';
// ─────────────────────────────────────────────────────────────────────────────
// Card decoration helper (spec-compliant, defined locally per file)
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _card(bool isDark) => BoxDecoration(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? AppColors.darkBorder : AppColors.borderLight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

// ─────────────────────────────────────────────────────────────────────────────
// Greeting helper
// ─────────────────────────────────────────────────────────────────────────────

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return tr('Good morning');
  if (hour < 17) return tr('Good afternoon');
  return tr('Good evening');
}

String _signed(double v) =>
    v >= 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);

String _availabilityLabel(ProductAvailability a) => switch (a) {
      ProductAvailability.inStock => 'In stock',
      ProductAvailability.limited => 'Limited',
      ProductAvailability.preOrder => 'Pre-order',
      ProductAvailability.soldOut => 'Sold out',
    };

Color _availabilityColor(ProductAvailability a) => switch (a) {
      ProductAvailability.inStock => AppColors.mintGreen,
      ProductAvailability.limited => AppColors.golden,
      ProductAvailability.preOrder => AppColors.infoBlue,
      ProductAvailability.soldOut => AppColors.errorRed,
    };

double _averageChangePct(List<Commodity> list) {
  if (list.isEmpty) return 0;
  return list.fold<double>(0, (s, c) => s + c.changePct) / list.length;
}

int _totalStockKg(List<ProductListing> list) => list
    .where((p) => p.availability != ProductAvailability.soldOut)
    .fold<int>(0, (s, p) => s + p.quantityKg);

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final commodities = ref.watch(commoditiesProvider);
    final buyers = ref.watch(buyersNearbyProvider);
    final products = ref.watch(productsProvider);
    final role = ref
        .watch(authSessionProvider.select((u) => u?.role ?? UserRole.farmer));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        title: T(
          'Operations',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            tooltip: tr('Search'),
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: tr('Notifications'),
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.deepGreen,
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(commoditiesProvider);
                ref.invalidate(buyersNearbyProvider);
                ref.invalidate(productsProvider);
                await Future.wait([
                  ref.read(commoditiesProvider.future),
                  ref.read(buyersNearbyProvider.future),
                  ref.read(productsProvider.future),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // [1] HERO BANNER
                  _HeroBanner(user: user, role: role)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.04, end: 0, duration: 400.ms),

                  const SizedBox(height: 16),

                  // Farmers can't be paid until a bank account is on file.
                  if (role == UserRole.farmer &&
                      ref.watch(myPayoutAccountProvider).hasValue &&
                      ref.watch(myPayoutAccountProvider).value == null) ...[
                    const _GetPaidPrompt(),
                    const SizedBox(height: 16),
                  ],

                  // [2] MARKET TICKER STRIP
                  commodities.when(
                    data: (list) => list.isNotEmpty
                        ? _MarketTickerStrip(commodities: list)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox(
                      height: 36,
                      child: Center(
                        child: LinearProgressIndicator(
                          color: AppColors.emerald,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 16),

                  // Buyers: farmers picked for them, and ones they viewed.
                  if (role == UserRole.buyer) const FarmersForYou(),

                  // [3] KPI GRID: farmer/buyer numbers. Transporters get
                  // their own dispatch figures below instead.
                  if (role != UserRole.transporter) ...[
                    _KpiGrid(
                      commodities: commodities,
                      buyers: buyers,
                      products: products,
                      // Farmers see their own listings and stock; "3 active
                      // listings" next to "1 listing" in My Listings confused.
                      sellerId: role == UserRole.farmer ? user?.id : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Role-specific sections
                  if (role == UserRole.transporter) ...[
                    // [7] TRANSPORTER WORKSPACE
                    SectionHeader(
                      title: tr('Dispatch Center'),
                      actionLabel: tr('Jobs'),
                      onAction: () => context.go('/main/market'),
                      icon: Icons.local_shipping_outlined,
                    ),
                    _TransporterWorkspace(
                      onMap: () => context.go('/main/market'),
                      onMessages: () => context.push('/main/messages'),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.03, end: 0, duration: 350.ms),
                    const SizedBox(height: 16),

                    SectionHeader(
                      title: tr('Nearby Hubs'),
                      actionLabel: tr('Map'),
                      onAction: () => context.push('/map'),
                      icon: Icons.store_mall_directory_outlined,
                    ),
                    buyers.when(
                      data: (list) => list.isEmpty
                          ? EmptyState(
                              icon: Icons.store_mall_directory_outlined,
                              title: tr('No hubs found'),
                              subtitle: tr(
                                  'Expand your delivery radius to see more hubs.'),
                              actionLabel: tr('Open Map'),
                              onAction: () => context.push('/map'),
                            )
                          : _BuyerPipeline(buyers: list),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SkeletonList(count: 3),
                      ),
                      error: (e, _) =>
                          _InlineError(message: tr('Hubs unavailable')),
                    ),

                    const SizedBox(height: 16),

                    // [8] QUICK ACTIONS
                    _QuickActions(user: user),
                  ] else ...[
                    // [4] MARKET WATCH
                    SectionHeader(
                      title: tr('Market Watch'),
                      actionLabel: tr('See all'),
                      onAction: () => context.push('/main/market/prices'),
                      icon: Icons.show_chart_rounded,
                    ),
                    commodities.when(
                      data: (list) => list.isEmpty
                          ? EmptyState(
                              icon: Icons.show_chart_rounded,
                              title: tr('No price data'),
                              subtitle: tr(
                                  'Market prices will appear here once available.'),
                            )
                          : _MarketWatch(
                              commodities: list,
                              onOpen: (id) =>
                                  context.push('/main/market/commodity/$id'),
                            ),
                      loading: () => const SizedBox(
                        height: 160,
                        child: SkeletonList(count: 2),
                      ),
                      error: (e, _) =>
                          _InlineError(message: tr('Prices unavailable')),
                    ),

                    const SizedBox(height: 16),

                    // [5] BUYER PIPELINE
                    SectionHeader(
                      title: tr('Active Buyers'),
                      actionLabel: tr('Map'),
                      onAction: () => context.push('/map'),
                      icon: Icons.handshake_outlined,
                    ),
                    buyers.when(
                      data: (list) => list.isEmpty
                          ? EmptyState(
                              icon: Icons.handshake_outlined,
                              title: tr('No buyers nearby'),
                              subtitle: tr(
                                  'Verified buyers will appear once data is loaded.'),
                              actionLabel: tr('Open Map'),
                              onAction: () => context.push('/map'),
                            )
                          : _BuyerPipeline(buyers: list),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SkeletonList(count: 3),
                      ),
                      error: (e, _) =>
                          _InlineError(message: tr('Buyers unavailable')),
                    ),

                    const SizedBox(height: 16),

                    // [6] PRIORITY LISTINGS
                    SectionHeader(
                      title: tr('Listings'),
                      actionLabel:
                          role == UserRole.farmer ? 'My Listings' : 'View all',
                      onAction: () => context.push(role == UserRole.farmer
                          ? '/my-listings'
                          : '/marketplace'),
                      icon: Icons.inventory_2_outlined,
                    ),
                    products.when(
                      data: (list) => list.isEmpty
                          ? EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: tr('No listings yet'),
                              subtitle: tr(
                                  'Add your first product to start selling.'),
                              actionLabel: tr('Add Listing'),
                              onAction: () => context.push('/marketplace/add'),
                            )
                          : _PriorityListings(
                              products: list,
                              onOpen: (id) =>
                                  context.push('/marketplace/product/$id'),
                            ),
                      loading: () => const SizedBox(
                        height: 140,
                        child: SkeletonList(count: 2),
                      ),
                      error: (e, _) =>
                          _InlineError(message: tr('Listings unavailable')),
                    ),

                    const SizedBox(height: 16),

                    // [8] QUICK ACTIONS
                    _QuickActions(user: user),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [1] Hero Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.user, required this.role});

  final AppUser? user;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Guest';
    final verified = user?.verified ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deepGreen, AppColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppAvatar(
                name: name,
                color: Colors.white.withValues(alpha: 0.25),
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two lines: "Good afternoon," on one, the name on the
                    // next, so the name is no longer cut to "Good aftern...".
                    Text(
                      '${_greeting()},',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    StatusBadge(
                      label: tr(switch (role) {
                        UserRole.farmer => 'Farmer',
                        UserRole.buyer => 'Buyer',
                        UserRole.transporter => 'Transporter',
                        UserRole.admin => 'Admin',
                      })
                          .toUpperCase(),
                      color: Colors.white,
                      icon: _roleIcon(role),
                    ),
                  ],
                ),
              ),
              // White, not green: green on the green banner was hard to read.
              if (verified)
                StatusBadge(
                  label: tr('Verified'),
                  color: Colors.white,
                  icon: Icons.verified_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.deepGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => switch (role) {
                    UserRole.farmer => context.push('/marketplace/add'),
                    UserRole.buyer => context.push('/marketplace'),
                    UserRole.transporter => context.go('/main/market'),
                    UserRole.admin => context.push('/admin'),
                  },
                  icon: Icon(
                    switch (role) {
                      UserRole.farmer => Icons.add_box_outlined,
                      UserRole.buyer => Icons.shopping_basket_outlined,
                      UserRole.transporter => Icons.route_outlined,
                      UserRole.admin => Icons.admin_panel_settings_outlined,
                    },
                    size: 18,
                  ),
                  label: Text(
                    tr(switch (role) {
                      UserRole.farmer => 'New Listing',
                      UserRole.buyer => 'Browse Produce',
                      UserRole.transporter => 'Find Jobs',
                      UserRole.admin => 'Admin Console',
                    }),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => switch (role) {
                    UserRole.farmer ||
                    UserRole.admin =>
                      context.push('/main/market/prices'),
                    UserRole.buyer => context.push('/map'),
                    UserRole.transporter => context.push('/main/messages'),
                  },
                  icon: Icon(
                    switch (role) {
                      UserRole.farmer ||
                      UserRole.admin =>
                        Icons.show_chart_rounded,
                      UserRole.buyer => Icons.map_outlined,
                      UserRole.transporter => Icons.chat_bubble_outline,
                    },
                    size: 18,
                  ),
                  label: Text(
                    tr(switch (role) {
                      UserRole.farmer || UserRole.admin => 'Market Prices',
                      UserRole.buyer => 'Buyer Map',
                      UserRole.transporter => 'Dispatch Chat',
                    }),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(UserRole role) => switch (role) {
        UserRole.farmer => Icons.grass_outlined,
        UserRole.buyer => Icons.shopping_basket_outlined,
        UserRole.transporter => Icons.local_shipping_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// [2] Market Ticker Strip
// ─────────────────────────────────────────────────────────────────────────────

class _MarketTickerStrip extends StatelessWidget {
  const _MarketTickerStrip({required this.commodities});

  final List<Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: T(
            'LIVE PRICES',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppColors.emerald,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: commodities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = commodities[i];
              final up = c.changePct >= 0;
              final pctColor = up ? AppColors.mintGreen : AppColors.errorRed;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatNgn(c.priceNgn),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.gray,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: pctColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              up
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 9,
                              color: pctColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${_signed(c.changePct)}%',
                            style: TextStyle(
                              color: pctColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (40 * i).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.05, end: 0, duration: 300.ms);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [3] KPI Grid
// ─────────────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.commodities,
    required this.buyers,
    required this.products,
    this.sellerId,
  });

  final AsyncValue<List<Commodity>> commodities;
  final AsyncValue<List<NearbyBuyer>> buyers;
  final AsyncValue<List<ProductListing>> products;

  /// When set (farmers), listing and stock tiles count only this seller's
  /// listings; otherwise they cover the whole marketplace.
  final String? sellerId;

  @override
  Widget build(BuildContext context) {
    final mine = sellerId != null;
    final scoped = products.whenData(
      (list) =>
          mine ? list.where((p) => p.sellerId == sellerId).toList() : list,
    );
    final activeListings = scoped.maybeWhen(
      data: (list) => list
          .where((p) => p.availability != ProductAvailability.soldOut)
          .length,
      orElse: () => null,
    );
    final verifiedBuyers = buyers.maybeWhen(
      data: (list) => list.where((b) => b.verified).length,
      orElse: () => null,
    );
    final avgChange = commodities.maybeWhen(
      data: _averageChangePct,
      orElse: () => null,
    );
    final stockKg = scoped.maybeWhen(
      data: _totalStockKg,
      orElse: () => null,
    );

    final marketMoveColor =
        (avgChange ?? 0) >= 0 ? AppColors.mintGreen : AppColors.errorRed;

    final cards = [
      StatCard(
        label: tr(mine ? 'My Active Listings' : 'Listings on Sale'),
        value: activeListings?.toString() ?? '—',
        icon: Icons.inventory_2_outlined,
        color: AppColors.deepGreen,
      ),
      StatCard(
        label: tr('Verified Buyers'),
        value: verifiedBuyers?.toString() ?? '—',
        icon: Icons.handshake_outlined,
        color: AppColors.infoBlue,
      ),
      StatCard(
        label: tr('Market Move'),
        value: avgChange == null ? '—' : '${_signed(avgChange)}%',
        icon: Icons.show_chart_rounded,
        color: marketMoveColor,
        trend: avgChange,
      ),
      StatCard(
        label: tr(mine ? 'My Stock' : 'Produce on Sale'),
        value: stockKg == null ? '—' : _compactKg(stockKg),
        icon: Icons.scale_outlined,
        color: AppColors.warmOrange,
        unit: stockKg != null && stockKg < 1000 ? 'kg' : null,
      ),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final isWide = constraints.maxWidth >= 560;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          childAspectRatio: isWide ? 1.4 : 1.3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: cards,
        );
      },
    );
  }

  String _compactKg(int kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}t';
    return '$kg';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [4] Market Watch — horizontal commodity cards
// ─────────────────────────────────────────────────────────────────────────────

class _MarketWatch extends StatelessWidget {
  const _MarketWatch({required this.commodities, required this.onOpen});

  final List<Commodity> commodities;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: commodities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = commodities[i];
          final up = c.changePct >= 0;
          final pctColor = up ? AppColors.mintGreen : AppColors.errorRed;
          final sparkColor = up ? AppColors.mintGreen : AppColors.errorRed;

          return GestureDetector(
            onTap: () => onOpen(c.id),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(14),
              decoration: _card(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: pctColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                up
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 11,
                                color: pctColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${_signed(c.changePct)}%',
                              style: TextStyle(
                                color: pctColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatNgn(c.priceNgn),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.charcoal,
                              ),
                            ),
                            Text(
                              'per ${c.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SparklineChart(
                        data: trendFromChange(c.changePct),
                        color: sparkColor,
                        height: 36,
                        width: 72,
                        strokeWidth: 1.8,
                        filled: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
              .animate(delay: (50 * i).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.03, end: 0, duration: 350.ms);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [5] Buyer Pipeline
// ─────────────────────────────────────────────────────────────────────────────

class _BuyerPipeline extends StatelessWidget {
  const _BuyerPipeline({required this.buyers});

  final List<NearbyBuyer> buyers;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visible = buyers.take(4).toList();

    return Column(
      children: List.generate(visible.length, (i) {
        final b = visible[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: _card(isDark),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: AppAvatar(
              name: b.name,
              color: AppColors.emerald,
              radius: 22,
            ),
            title: Text(
              b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
              ),
            ),
            subtitle: Text(
              '${b.type} · ${b.state} · ${b.distanceKm} km',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (b.verified) ...[
                  StatusBadge(
                    label: tr('Verified'),
                    color: AppColors.mintGreen,
                    icon: Icons.verified_rounded,
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(Icons.star_rounded,
                          size: 13, color: AppColors.golden),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      b.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate(delay: (50 * i).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.03, end: 0, duration: 350.ms);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [6] Priority Listings
// ─────────────────────────────────────────────────────────────────────────────

class _PriorityListings extends StatelessWidget {
  const _PriorityListings({required this.products, required this.onOpen});

  final List<ProductListing> products;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visible = products.take(3).toList();

    return Column(
      children: List.generate(visible.length, (i) {
        final p = visible[i];
        return GestureDetector(
          onTap: () => onOpen(p.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _card(isDark),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Product image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ProduceImage(
                      url: p.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${p.quantityKg} kg · ${p.city}, ${p.state}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Price + availability
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatNgn(p.priceNgn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StatusBadge(
                        label: _availabilityLabel(p.availability),
                        color: _availabilityColor(p.availability),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
            .animate(delay: (50 * i).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.03, end: 0, duration: 350.ms);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [7] Transporter Workspace
// ─────────────────────────────────────────────────────────────────────────────

class _TransporterWorkspace extends ConsumerWidget {
  const _TransporterWorkspace({
    required this.onMap,
    required this.onMessages,
  });

  final VoidCallback onMap;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final openJobs = ref.watch(openHaulageJobsProvider).valueOrNull;
    final myJobs = ref.watch(myHaulageJobsProvider).valueOrNull;
    final myId = ref.watch(authSessionProvider.select((u) => u?.id));
    final openCount =
        openJobs?.where((j) => j.buyerId != myId && j.sellerId != myId).length;
    final active = myJobs?.where((j) => j.isActive).toList();
    final delivered = myJobs?.where((j) => j.isDelivered).toList();
    final earned = delivered?.fold<int>(0, (s, j) => s + j.offerNgn);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T(
            'Dispatch Stats',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 14),
          _DispatchRow(
            icon: Icons.local_shipping_outlined,
            title: tr('Open jobs'),
            value: openCount != null ? '$openCount' : '—',
            status: 'Waiting for a transporter',
            color: AppColors.deepGreen,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _DispatchRow(
            icon: Icons.sensors_rounded,
            title: tr('Under way'),
            value: active != null ? '${active.length}' : '—',
            status: active == null || active.isEmpty
                ? 'No delivery in progress'
                : active.first.statusLabel,
            color: AppColors.infoBlue,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _DispatchRow(
            icon: Icons.task_alt_rounded,
            title: tr('Delivered'),
            value: delivered != null ? '${delivered.length}' : '—',
            status: earned == null || earned == 0
                ? 'Completed deliveries'
                : '${formatNgn(earned)} agreed in total',
            color: AppColors.golden,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onMap,
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const T(
                    'Find Jobs',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepGreen,
                    side: const BorderSide(color: AppColors.deepGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onMessages,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const T(
                    'Dispatch Chat',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DispatchRow extends StatelessWidget {
  const _DispatchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color:
                      isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.gray,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [8] Quick Actions
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final role = user?.role ?? UserRole.farmer;
    final buttons = _buttonsForRole(context, role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: T(
            'QUICK ACTIONS',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppColors.emerald,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(buttons.length, (i) {
            return buttons[i]
                .animate(delay: (40 * i).ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.03, end: 0, duration: 300.ms);
          }),
        ),
      ],
    );
  }

  List<Widget> _buttonsForRole(BuildContext context, UserRole role) {
    final settings = FilledButton.tonalIcon(
      onPressed: () => context.push('/settings'),
      icon: const Icon(Icons.tune_outlined, size: 16),
      label: const T('Settings',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
    );

    return switch (role) {
      UserRole.farmer => [
          FilledButton.tonalIcon(
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.storefront_outlined, size: 16),
            label: const T('Marketplace',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/marketplace/add'),
            icon: const Icon(Icons.add_box_outlined, size: 16),
            label: const T('Add Product',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/main/market/prices'),
            icon: const Icon(Icons.show_chart_rounded, size: 16),
            label: const T('Prices',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          settings,
        ],
      UserRole.buyer => [
          FilledButton.tonalIcon(
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.shopping_basket_outlined, size: 16),
            label: const T('Source Produce',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/map'),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const T('Buyer Map',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/main/market/prices'),
            icon: const Icon(Icons.show_chart_rounded, size: 16),
            label: const T('Market',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          settings,
        ],
      UserRole.transporter => [
          FilledButton.tonalIcon(
            onPressed: () => context.go('/main/market'),
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: const T('Jobs',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/main/messages'),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const T('Dispatch Chat',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const T('Cargo Board',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          settings,
        ],
      UserRole.admin => [
          FilledButton.tonalIcon(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
            label: const T('Admin Console',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/marketplace'),
            icon: const Icon(Icons.storefront_outlined, size: 16),
            label: const T('Listings',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/main/market/prices'),
            icon: const Icon(Icons.show_chart_rounded, size: 16),
            label: const T('Market',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
          settings,
        ],
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline Error
// ─────────────────────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.errorRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown to farmers until they add a bank account for their sales.
class _GetPaidPrompt extends StatelessWidget {
  const _GetPaidPrompt();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.golden.withValues(alpha: isDark ? 0.16 : 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/payouts'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.account_balance_outlined,
                  color: isDark ? AppColors.golden : AppColors.warningOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('Add your bank account',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(isDark))),
                    const SizedBox(height: 2),
                    T(
                      'Buyers can pay for your produce once your bank '
                      'account is set. Takes a minute.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.subText(isDark)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.subText(isDark)),
            ],
          ),
        ),
      ),
    );
  }
}

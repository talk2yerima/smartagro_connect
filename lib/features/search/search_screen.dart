import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/entities/nearby_buyer.dart';
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Card decoration helper
// ---------------------------------------------------------------------------
BoxDecoration _card(bool isDark) => BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Trending category data
// ---------------------------------------------------------------------------
class _TrendingCategory {
  const _TrendingCategory({
    required this.name,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final String name;
  final IconData icon;
  final Color gradientStart;
  final Color gradientEnd;
}

const List<_TrendingCategory> _trendingCategories = [
  _TrendingCategory(
    name: 'Maize',
    icon: Icons.grain,
    gradientStart: Color(0xFFF9A825),
    gradientEnd: Color(0xFFFF8F00),
  ),
  _TrendingCategory(
    name: 'Tomatoes',
    icon: Icons.eco,
    gradientStart: Color(0xFFE53935),
    gradientEnd: Color(0xFFC62828),
  ),
  _TrendingCategory(
    name: 'Cassava',
    icon: Icons.spa,
    gradientStart: Color(0xFF6D4C41),
    gradientEnd: Color(0xFF4E342E),
  ),
  _TrendingCategory(
    name: 'Rice',
    icon: Icons.rice_bowl,
    gradientStart: Color(0xFF1B5E20),
    gradientEnd: Color(0xFF2E7D32),
  ),
  _TrendingCategory(
    name: 'Yam',
    icon: Icons.local_dining,
    gradientStart: Color(0xFFFB8C00),
    gradientEnd: Color(0xFFE65100),
  ),
  _TrendingCategory(
    name: 'Palm Oil',
    icon: Icons.opacity,
    gradientStart: Color(0xFF0277BD),
    gradientEnd: Color(0xFF01579B),
  ),
];

const List<String> _mockRecentSearches = [
  'Maize Plateau',
  'Tomatoes Lagos',
  'Rice Kebbi',
  'Cassava Oyo',
  'Palm Oil Rivers',
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;

  String _query = '';
  bool _verifiedOnly = false;
  bool _priceFilterActive = false;
  bool _nearbyOnly = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = _searchController.text.trim();
      if (mounted && q != _query) setState(() => _query = q);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  void _applyRecentSearch(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
  }

  void _applyCategory(String name) {
    _searchController.text = name;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: name.length),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.softWhite;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark),
      body: _query.isEmpty ? _buildEmptyState(isDark) : _buildResults(isDark),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
          ),
          decoration: InputDecoration(
            hintText: 'Search crops, products, buyers…',
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
                    ),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          ),
        ),
      ),
      titleSpacing: 0,
    );
  }

  // ── Empty state (no query) ───────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark) {
    return RefreshIndicator(
      color: AppColors.deepGreen,
      onRefresh: () async {
        ref.invalidate(commoditiesProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(buyersNearbyProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          // ── Recent Searches ──
          const SectionHeader(
            title: 'Recent Searches',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 8),
          _buildRecentSearches(isDark),
          const SizedBox(height: 16),
          // ── Trending Categories ──
          const SectionHeader(
            title: 'Trending Categories',
            icon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 8),
          _buildTrendingGrid(isDark),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_mockRecentSearches.length, (i) {
          final term = _mockRecentSearches[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                Icons.history_rounded,
                size: 15,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
              ),
              label: Text(
                term,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
                ),
              ),
              backgroundColor:
                  isDark ? AppColors.darkSurface : AppColors.surfaceLight,
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
              onPressed: () => _applyRecentSearch(term),
            )
                .animate(delay: (40 * i).ms)
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.06),
          );
        }),
      ),
    );
  }

  Widget _buildTrendingGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _trendingCategories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (context, i) {
          final cat = _trendingCategories[i];
          return _TrendingCategoryCard(
            category: cat,
            index: i,
            onTap: () => _applyCategory(cat.name),
          );
        },
      ),
    );
  }

  // ── Search Results ───────────────────────────────────────────────────────

  Widget _buildResults(bool isDark) {
    final commoditiesAsync = ref.watch(commoditiesProvider);
    final productsAsync = ref.watch(productsProvider);
    final buyersAsync = ref.watch(buyersNearbyProvider);

    final q = _query.toLowerCase();

    final commodities = commoditiesAsync.valueOrNull
            ?.where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.category.toLowerCase().contains(q))
            .toList() ??
        [];

    final products = productsAsync.valueOrNull
            ?.where((p) {
              final matchQ = p.title.toLowerCase().contains(q) ||
                  p.state.toLowerCase().contains(q) ||
                  p.city.toLowerCase().contains(q) ||
                  p.sellerName.toLowerCase().contains(q);
              final matchVerified = !_verifiedOnly || p.verified;
              final matchNearby = !_nearbyOnly;
              return matchQ && matchVerified && matchNearby;
            })
            .toList() ??
        [];

    final buyers = buyersAsync.valueOrNull
            ?.where((b) {
              final matchQ = b.name.toLowerCase().contains(q) ||
                  b.type.toLowerCase().contains(q) ||
                  b.state.toLowerCase().contains(q);
              final matchVerified = !_verifiedOnly || b.verified;
              final matchNearby = !_nearbyOnly || b.distanceKm <= 50;
              return matchQ && matchVerified && matchNearby;
            })
            .toList() ??
        [];

    final isLoading = commoditiesAsync.isLoading ||
        productsAsync.isLoading ||
        buyersAsync.isLoading;

    return Column(
      children: [
        // ── Tabs ──
        Container(
          color: isDark ? AppColors.cardDark : Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            labelColor: AppColors.deepGreen,
            unselectedLabelColor:
                isDark ? AppColors.darkTextSecondary : AppColors.gray,
            indicatorColor: AppColors.deepGreen,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Commodities'),
              Tab(text: 'Products'),
              Tab(text: 'Buyers'),
            ],
          ),
        ),
        // ── Filter chips ──
        _buildFilterRow(isDark),
        // ── Results ──
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.deepGreen),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllTab(
                        isDark, commodities, products, buyers),
                    _buildCommoditiesTab(isDark, commodities),
                    _buildProductsTab(isDark, products),
                    _buildBuyersTab(isDark, buyers),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'Verified Only',
              icon: Icons.verified_rounded,
              selected: _verifiedOnly,
              isDark: isDark,
              onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Within 50 km',
              icon: Icons.location_on_rounded,
              selected: _nearbyOnly,
              isDark: isDark,
              onTap: () => setState(() => _nearbyOnly = !_nearbyOnly),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Price: Low-High',
              icon: Icons.sort_rounded,
              selected: _priceFilterActive,
              isDark: isDark,
              onTap: () =>
                  setState(() => _priceFilterActive = !_priceFilterActive),
            ),
          ],
        ),
      ),
    );
  }

  // ── All tab ──────────────────────────────────────────────────────────────

  Widget _buildAllTab(
    bool isDark,
    List<Commodity> commodities,
    List<ProductListing> products,
    List<NearbyBuyer> buyers,
  ) {
    final hasAny =
        commodities.isNotEmpty || products.isNotEmpty || buyers.isNotEmpty;

    if (!hasAny) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try different keywords or adjust your filters.',
      );
    }

    return RefreshIndicator(
      color: AppColors.deepGreen,
      onRefresh: () async {
        ref.invalidate(commoditiesProvider);
        ref.invalidate(productsProvider);
        ref.invalidate(buyersNearbyProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (commodities.isNotEmpty) ...[
            const SizedBox(height: 4),
            SectionHeader(
              title: 'Commodities',
              actionLabel: commodities.length > 2 ? 'See all' : null,
              onAction: () => _tabController.animateTo(1),
            ),
            ...commodities.take(2).toList().asMap().entries.map((e) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _CommodityTile(
                  commodity: e.value,
                  isDark: isDark,
                  index: e.key,
                ),
              );
            }),
          ],
          if (products.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(
              title: 'Products',
              actionLabel: products.length > 2 ? 'See all' : null,
              onAction: () => _tabController.animateTo(2),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: products.take(2).toList().asMap().entries.map((e) {
                return _ProductCard(
                  product: e.value,
                  isDark: isDark,
                  index: e.key,
                );
              }).toList(),
            ),
          ],
          if (buyers.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader(
              title: 'Buyers',
              actionLabel: buyers.length > 2 ? 'See all' : null,
              onAction: () => _tabController.animateTo(3),
            ),
            ...buyers.take(2).toList().asMap().entries.map((e) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _BuyerTile(
                  buyer: e.value,
                  isDark: isDark,
                  index: e.key,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Commodities tab ──────────────────────────────────────────────────────

  Widget _buildCommoditiesTab(bool isDark, List<Commodity> commodities) {
    if (commodities.isEmpty) {
      return const EmptyState(
        icon: Icons.grain,
        title: 'No commodities found',
        subtitle: 'Try searching with a different crop or category name.',
      );
    }

    return RefreshIndicator(
      color: AppColors.deepGreen,
      onRefresh: () async => ref.invalidate(commoditiesProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: commodities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _CommodityTile(
          commodity: commodities[i],
          isDark: isDark,
          index: i,
        ),
      ),
    );
  }

  // ── Products tab ─────────────────────────────────────────────────────────

  Widget _buildProductsTab(bool isDark, List<ProductListing> products) {
    if (products.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_rounded,
        title: 'No products found',
        subtitle: 'Try searching by crop name, location, or seller.',
      );
    }

    return RefreshIndicator(
      color: AppColors.deepGreen,
      onRefresh: () async => ref.invalidate(productsProvider),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) => _ProductCard(
          product: products[i],
          isDark: isDark,
          index: i,
        ),
      ),
    );
  }

  // ── Buyers tab ───────────────────────────────────────────────────────────

  Widget _buildBuyersTab(bool isDark, List<NearbyBuyer> buyers) {
    if (buyers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_alt_rounded,
        title: 'No buyers found',
        subtitle: 'Try a different search term or remove filters.',
      );
    }

    return RefreshIndicator(
      color: AppColors.deepGreen,
      onRefresh: () async => ref.invalidate(buyersNearbyProvider),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: buyers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _BuyerTile(
          buyer: buyers[i],
          isDark: isDark,
          index: i,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.deepGreen;
    final bg = selected
        ? activeColor.withValues(alpha: 0.12)
        : (isDark ? AppColors.cardDark : Colors.white);
    final border = selected
        ? activeColor.withValues(alpha: 0.5)
        : (isDark ? AppColors.darkBorder : AppColors.borderLight);
    final textColor = selected
        ? activeColor
        : (isDark ? AppColors.darkTextSecondary : AppColors.gray);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trending category card
// ---------------------------------------------------------------------------

class _TrendingCategoryCard extends StatelessWidget {
  const _TrendingCategoryCard({
    required this.category,
    required this.index,
    required this.onTap,
  });

  final _TrendingCategory category;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [category.gradientStart, category.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: category.gradientStart.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// Commodity tile
// ---------------------------------------------------------------------------

class _CommodityTile extends StatelessWidget {
  const _CommodityTile({
    required this.commodity,
    required this.isDark,
    required this.index,
  });

  final Commodity commodity;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isUp = commodity.changePct >= 0;
    final changeColor =
        isUp ? AppColors.mintGreen : AppColors.errorRed;
    final changeIcon = isUp
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final changeLabel =
        '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(1)}%';

    return Container(
      decoration: _card(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // ── Category icon bubble ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.deepGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.grain,
              color: AppColors.deepGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // ── Name + category ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commodity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  commodity.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.gray,
                  ),
                ),
              ],
            ),
          ),
          // ── Price + trend ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatNgn(commodity.priceNgn)}/${commodity.unit}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(changeIcon, size: 11, color: changeColor),
                  const SizedBox(width: 2),
                  Text(
                    changeLabel,
                    style: TextStyle(
                      color: changeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// Product card (2-col grid)
// ---------------------------------------------------------------------------

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isDark,
    required this.index,
  });

  final ProductListing product;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(isDark),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image placeholder ──
          Container(
            height: 90,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.deepGreen, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: product.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    memCacheHeight: 270,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported_rounded,
                      color: Colors.white54,
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.city}, ${product.state}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        formatNgn(product.priceNgn),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                    if (product.verified)
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.infoBlue,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// Buyer tile
// ---------------------------------------------------------------------------

class _BuyerTile extends StatelessWidget {
  const _BuyerTile({
    required this.buyer,
    required this.isDark,
    required this.index,
  });

  final NearbyBuyer buyer;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // ── Avatar ──
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.deepGreen, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                buyer.name.isNotEmpty ? buyer.name[0].toUpperCase() : 'B',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        buyer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.charcoal,
                        ),
                      ),
                    ),
                    if (buyer.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.infoBlue,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  buyer.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      buyer.state,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.gray,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.near_me_rounded,
                      size: 12,
                      color: AppColors.freshGreen,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${buyer.distanceKm} km away',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.freshGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Rating ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: AppColors.golden),
                  const SizedBox(width: 2),
                  Text(
                    buyer.rating.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.golden,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              StatusBadge(
                label: buyer.verified ? 'Verified' : 'Unverified',
                color: buyer.verified
                    ? AppColors.mintGreen
                    : AppColors.gray,
                icon: buyer.verified
                    ? Icons.verified_rounded
                    : Icons.help_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04);
  }
}

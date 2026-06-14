import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/empty_state.dart';

// ─── Category model ──────────────────────────────────────────────────────────

enum _Category {
  all('All'),
  grains('Grains'),
  vegetables('Vegetables'),
  fruits('Fruits'),
  livestock('Livestock'),
  oilseeds('Oilseeds');

  const _Category(this.label);
  final String label;
}

// ─── Sort options ─────────────────────────────────────────────────────────────

enum _SortOption {
  newest('Newest'),
  priceLow('Price: Low'),
  priceHigh('Price: High'),
  rating('Top Rated');

  const _SortOption(this.label);
  final String label;
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchController = TextEditingController();
  _Category _selectedCategory = _Category.all;
  _SortOption _selectedSort = _SortOption.newest;
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  // ── Filtering + sorting ───────────────────────────────────────────────────

  List<ProductListing> _applyFilters(List<ProductListing> all) {
    var results = all.where((p) {
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty &&
          !p.title.toLowerCase().contains(q) &&
          !p.city.toLowerCase().contains(q) &&
          !p.state.toLowerCase().contains(q) &&
          !p.sellerName.toLowerCase().contains(q)) {
        return false;
      }

      if (_selectedCategory != _Category.all) {
        // Simple keyword-based category match
        final cat = _selectedCategory.label.toLowerCase();
        final title = p.title.toLowerCase();
        final desc = p.description.toLowerCase();
        if (!title.contains(cat) && !desc.contains(cat)) return false;
      }

      return true;
    }).toList();

    switch (_selectedSort) {
      case _SortOption.newest:
        break; // preserve server order
      case _SortOption.priceLow:
        results.sort((a, b) => a.priceNgn.compareTo(b.priceNgn));
      case _SortOption.priceHigh:
        results.sort((a, b) => b.priceNgn.compareTo(a.priceNgn));
      case _SortOption.rating:
        results.sort((a, b) => b.sellerRating.compareTo(a.sellerRating));
    }

    return results;
  }

  // ── Sort bottom sheet ─────────────────────────────────────────────────────

  void _showSortSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(isDark),
                  ),
            ),
            const SizedBox(height: 12),
            ..._SortOption.values.map(
              (opt) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: _selectedSort == opt
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedSort == opt
                        ? AppColors.deepGreen
                        : AppColors.text(isDark),
                  ),
                ),
                trailing: _selectedSort == opt
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.deepGreen, size: 18)
                    : null,
                onTap: () {
                  setState(() => _selectedSort = opt);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authSessionProvider);
    final canAddListing =
        user?.role == UserRole.farmer || user?.role == UserRole.admin;
    final async = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        title: Text(
          'Marketplace',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: AppColors.text(isDark),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showSortSheet,
            tooltip: 'Sort & Filter',
            icon: Icon(
              Icons.tune_rounded,
              color: AppColors.text(isDark),
            ),
          ),
          if (canAddListing)
            IconButton(
              onPressed: () => context.push('/marketplace/add'),
              tooltip: 'Add listing',
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.deepGreen,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => _LoadingGrid(isDark: isDark),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 48,
                    color: AppColors.gray.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Failed to load listings',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(productsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepGreen,
                    side: const BorderSide(color: AppColors.deepGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          final filtered = _applyFilters(items);
          return RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () async => ref.invalidate(productsProvider),
            child: CustomScrollView(
              slivers: [
                // ── Search + filter row ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _SearchFilterRow(
                      controller: _searchController,
                      isDark: isDark,
                      onChanged: _onSearchChanged,
                      onSortTap: _showSortSheet,
                      sortLabel: _selectedSort.label,
                    ),
                  ),
                ),

                // ── Category chips ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    selected: _selectedCategory,
                    isDark: isDark,
                    onSelected: (c) =>
                        setState(() => _selectedCategory = c),
                  ),
                ),

                // ── Stats bar ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Text(
                      '${filtered.length} listing${filtered.length == 1 ? '' : 's'}'
                      ' · Updated now',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.gray,
                            fontSize: 11,
                          ),
                    ),
                  ),
                ),

                // ── Product grid ────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No listings',
                      subtitle: 'Be the first to list your produce',
                      actionLabel:
                          canAddListing ? 'Add listing' : null,
                      onAction: canAddListing
                          ? () => context.push('/marketplace/add')
                          : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = filtered[i];
                          return _ProductCard(
                            key: ValueKey(p.id),
                            product: p,
                            isDark: isDark,
                            index: i,
                          );
                        },
                        findChildIndexCallback: (key) {
                          final id = (key as ValueKey<String>).value;
                          final idx = filtered.indexWhere((p) => p.id == id);
                          return idx == -1 ? null : idx;
                        },
                        childCount: filtered.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Search + Filter Row ──────────────────────────────────────────────────────

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.controller,
    required this.isDark,
    required this.onChanged,
    required this.onSortTap,
    required this.sortLabel,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onSortTap;
  final String sortLabel;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        isDark ? AppColors.cardDark : AppColors.surfaceLight;
    final borderColor =
        isDark ? const Color(0xFF2E3C2E) : AppColors.borderLight;

    return Row(
      children: [
        // ── Search field ────────────────────────────────────────────────
        Expanded(
          child: TextFormField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.text(isDark),
            ),
            decoration: InputDecoration(
              hintText: 'Search produce, location…',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.gray.withValues(alpha: 0.7),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.gray,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.gray),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.deepGreen, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Sort button ──────────────────────────────────────────────────
        GestureDetector(
          onTap: onSortTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded,
                    size: 16, color: AppColors.deepGreen),
                const SizedBox(width: 4),
                Text(
                  sortLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Category Chips ───────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.isDark,
    required this.onSelected,
  });

  final _Category selected;
  final bool isDark;
  final ValueChanged<_Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _Category.values.map((cat) {
          final isSelected = cat == selected;
          return Padding(
            key: ValueKey(cat),
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(cat);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.deepGreen
                      : (isDark
                          ? AppColors.cardDark
                          : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.deepGreen
                        : (isDark
                            ? const Color(0xFF2E3C2E)
                            : AppColors.borderLight),
                  ),
                ),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : AppColors.subText(isDark),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Product Card ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    super.key,
    required this.product,
    required this.isDark,
    required this.index,
  });

  final ProductListing product;
  final bool isDark;
  final int index;

  Color get _availabilityColor {
    switch (product.availability) {
      case ProductAvailability.inStock:
        return AppColors.freshGreen;
      case ProductAvailability.limited:
        return AppColors.golden;
      case ProductAvailability.soldOut:
        return AppColors.errorRed;
    }
  }

  String get _availabilityLabel {
    switch (product.availability) {
      case ProductAvailability.inStock:
        return 'In Stock';
      case ProductAvailability.limited:
        return 'Limited';
      case ProductAvailability.soldOut:
        return 'Sold Out';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('/marketplace/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image + badges ─────────────────────────────────────────
            Stack(
              children: [
                // Product image
                Hero(
                  tag: 'product-image-${product.id}',
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 140,
                      memCacheWidth: 400,
                      memCacheHeight: 280,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade50,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F4EE),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: AppColors.gray.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Availability badge — top left
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _availabilityColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _availabilityLabel,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // Price badge — top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9A825).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatNgn(product.priceNgn),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            // ── Content area ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.text(isDark),
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.gray,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            '${product.city}, ${product.state}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.gray,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom row: rating + quantity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Star rating
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (starIdx) {
                              final filled =
                                  starIdx < product.sellerRating.round();
                              return Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: filled
                                    ? AppColors.golden
                                    : AppColors.gray
                                        .withValues(alpha: 0.3),
                              );
                            }),
                            const SizedBox(width: 3),
                            Text(
                              product.sellerRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),

                        // Quantity chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.deepGreen
                                    .withValues(alpha: 0.25)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${product.quantityKg}kg',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
          .animate(delay: (40 * index).ms)
          .fadeIn(duration: 280.ms)
          .scale(
            begin: const Offset(0.97, 0.97),
            duration: 280.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ─── Loading skeleton grid ────────────────────────────────────────────────────

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _SkeletonCard(isDark: isDark),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
      highlightColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade50,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // image area
            Container(
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 13,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      Container(
                        height: 18,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Local helpers
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
// ProductDetailScreen
// ---------------------------------------------------------------------------

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsProvider);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          title: Text(
            'Product',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        body: const SkeletonList(count: 6),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          title: Text(
            'Product',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        body: Center(
          child: Text(
            'Failed to load product.\n$e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (items) {
        final matchIndex = items.indexWhere((e) => e.id == productId);
        if (matchIndex == -1) {
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0.5,
              title: Text(
                'Not Found',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
            body: const Center(child: Text('Product not found.')),
          );
        }
        final product = items[matchIndex];
        final similar = items
            .where((e) => e.id != product.id)
            .take(6)
            .toList(growable: false);

        return _ProductDetailView(
          product: product,
          similar: similar,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _ProductDetailView
// ---------------------------------------------------------------------------

class _ProductDetailView extends StatefulWidget {
  const _ProductDetailView({
    required this.product,
    required this.similar,
  });

  final ProductListing product;
  final List<ProductListing> similar;

  @override
  State<_ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<_ProductDetailView> {
  bool _bookmarked = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBg : AppColors.softWhite,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Main scroll content ──────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // [0] SliverAppBar with hero image
              _buildSliverAppBar(context, isDark, p),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [1] Price hero
                    _PriceHeroSection(product: p, isDark: isDark)
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.04),

                    const SizedBox(height: 12),

                    // [2] Seller card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SellerCard(product: p, isDark: isDark),
                    ).animate(delay: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.04),

                    const SizedBox(height: 12),

                    // [3] Details card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _DetailsCard(product: p, isDark: isDark),
                    ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.04),

                    const SizedBox(height: 12),

                    // [4] Description
                    if (p.description.trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _DescriptionCard(
                            description: p.description, isDark: isDark),
                      ).animate(delay: 150.ms).fadeIn(duration: 300.ms).slideY(begin: 0.04),
                      const SizedBox(height: 12),
                    ],

                    // [5] Similar listings
                    if (widget.similar.isNotEmpty) ...[
                      const SectionHeader(
                        title: 'Similar Listings',
                        icon: Icons.grid_view_rounded,
                      ),
                      _SimilarListingsRow(items: widget.similar, isDark: isDark)
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.04),
                      const SizedBox(height: 12),
                    ],

                    // Bottom padding to clear sticky bar
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ],
          ),

          // ── Sticky bottom bar ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(product: p, isDark: isDark),
          ),
        ],
      ),
    );
  }

  // ── SliverAppBar ─────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(
      BuildContext context, bool isDark, ProductListing p) {
    return SliverAppBar(
      expandedHeight: 260,
      floating: true,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor:
          isDark ? const Color(0xFF121212) : Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          isDark: isDark,
          onTap: () => context.pop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _CircleIconButton(
            icon: Icons.share_rounded,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share link copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _CircleIconButton(
            icon: _bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            isDark: isDark,
            activeColor: AppColors.deepGreen,
            isActive: _bookmarked,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _bookmarked = !_bookmarked);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _bookmarked ? 'Removed from saved' : 'Saved to bookmarks',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'product-image-${p.id}',
              child: CachedNetworkImage(
                imageUrl: p.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark
                      ? AppColors.cardDark
                      : AppColors.surfaceLight,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark
                      ? AppColors.cardDark
                      : AppColors.surfaceLight,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppColors.gray,
                  ),
                ),
              ),
            ),
            // Bottom gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CircleIconButton
// ---------------------------------------------------------------------------

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.activeColor,
    this.isActive = false,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final Color? activeColor;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);
    final iconColor = isActive && activeColor != null
        ? activeColor!
        : (isDark ? Colors.white : AppColors.charcoal);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// [1] _PriceHeroSection
// ---------------------------------------------------------------------------

class _PriceHeroSection extends StatelessWidget {
  const _PriceHeroSection({required this.product, required this.isDark});

  final ProductListing product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final availColor = _availColor(product.availability);
    final availLabel = _availLabel(product.availability);
    final availIcon = _availIcon(product.availability);
    final textColor = AppColors.text(isDark);
    final subTextColor = AppColors.subText(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price row + availability badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${formatNgn(product.priceNgn)} / kg',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                label: availLabel,
                color: availColor,
                icon: availIcon,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.3,
                ),
          ),

          const SizedBox(height: 10),

          // Location + category chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(
                icon: Icons.location_on_rounded,
                label: '${product.city}, ${product.state}',
                isDark: isDark,
              ),
              _InfoChip(
                icon: Icons.category_rounded,
                label: _inferCategory(product.title),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Quantity sub-text
          Text(
            '${product.quantityKg} kg available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Color _availColor(ProductAvailability av) {
    switch (av) {
      case ProductAvailability.inStock:
        return AppColors.freshGreen;
      case ProductAvailability.limited:
        return AppColors.warmOrange;
      case ProductAvailability.soldOut:
        return AppColors.errorRed;
    }
  }

  String _availLabel(ProductAvailability av) {
    switch (av) {
      case ProductAvailability.inStock:
        return 'In Stock';
      case ProductAvailability.limited:
        return 'Limited';
      case ProductAvailability.soldOut:
        return 'Sold Out';
    }
  }

  IconData _availIcon(ProductAvailability av) {
    switch (av) {
      case ProductAvailability.inStock:
        return Icons.check_circle_outline_rounded;
      case ProductAvailability.limited:
        return Icons.hourglass_bottom_rounded;
      case ProductAvailability.soldOut:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String _inferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('rice')) return 'Rice';
    if (t.contains('maize') || t.contains('corn')) return 'Maize';
    if (t.contains('cassava')) return 'Cassava';
    if (t.contains('yam')) return 'Yam';
    if (t.contains('tomato')) return 'Tomatoes';
    if (t.contains('pepper')) return 'Peppers';
    if (t.contains('cocoa')) return 'Cocoa';
    if (t.contains('palm')) return 'Palm Produce';
    if (t.contains('soybean') || t.contains('soya')) return 'Soybean';
    if (t.contains('groundnut') || t.contains('peanut')) return 'Groundnut';
    if (t.contains('fish')) return 'Fish';
    if (t.contains('poultry') || t.contains('chicken')) return 'Poultry';
    return 'Produce';
  }
}

// ---------------------------------------------------------------------------
// _InfoChip
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.deepGreen.withValues(alpha: 0.15)
            : AppColors.deepGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.deepGreen.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.deepGreen),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.deepGreen,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// [2] _SellerCard
// ---------------------------------------------------------------------------

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.product, required this.isDark});

  final ProductListing product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(isDark);
    final subTextColor = AppColors.subText(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              AppAvatar(
                name: product.sellerName,
                color: AppColors.emerald,
                radius: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                          ),
                        ),
                        if (product.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.infoBlue,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    StatusBadge(
                      label: product.verified ? 'Verified Farmer' : 'Farmer',
                      color: product.verified
                          ? AppColors.infoBlue
                          : AppColors.gray,
                      icon: Icons.agriculture_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Star rating
          _StarRating(rating: product.sellerRating, subTextColor: subTextColor),

          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening chat with seller...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                  label: const Text('Contact Seller'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Viewing seller profile...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepGreen,
                    side: const BorderSide(color: AppColors.deepGreen),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

// ---------------------------------------------------------------------------
// _StarRating
// ---------------------------------------------------------------------------

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.subTextColor});

  final double rating;
  final Color subTextColor;

  @override
  Widget build(BuildContext context) {
    final filled = rating.floor();
    final hasHalf = (rating - filled) >= 0.5;

    return Row(
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < filled
                ? Icons.star_rounded
                : (i == filled && hasHalf)
                    ? Icons.star_half_rounded
                    : Icons.star_border_rounded,
            size: 16,
            color: AppColors.golden,
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: subTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// [3] _DetailsCard
// ---------------------------------------------------------------------------

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.product, required this.isDark});

  final ProductListing product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(isDark);
    final subTextColor = AppColors.subText(isDark);

    final details = <({IconData icon, String label, String value})>[
      (
        icon: Icons.scale_rounded,
        label: 'Quantity',
        value: '${product.quantityKg} kg',
      ),
      (
        icon: Icons.category_rounded,
        label: 'Category',
        value: _inferCategory(product.title),
      ),
      (
        icon: Icons.location_on_rounded,
        label: 'Location',
        value: '${product.city}, ${product.state}',
      ),
      (
        icon: Icons.calendar_today_rounded,
        label: 'Listed',
        value: 'Recently',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, i) {
              final d = details[i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.deepGreen.withValues(alpha: 0.10)
                      : AppColors.softWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E3C2E)
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(d.icon, size: 16, color: AppColors.freshGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: subTextColor,
                                      fontSize: 10,
                                    ),
                          ),
                          Text(
                            d.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _inferCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('rice')) return 'Rice';
    if (t.contains('maize') || t.contains('corn')) return 'Maize';
    if (t.contains('cassava')) return 'Cassava';
    if (t.contains('yam')) return 'Yam';
    if (t.contains('tomato')) return 'Tomatoes';
    if (t.contains('pepper')) return 'Peppers';
    if (t.contains('cocoa')) return 'Cocoa';
    if (t.contains('palm')) return 'Palm Produce';
    if (t.contains('soybean') || t.contains('soya')) return 'Soybean';
    if (t.contains('groundnut') || t.contains('peanut')) return 'Groundnut';
    if (t.contains('fish')) return 'Fish';
    if (t.contains('poultry') || t.contains('chicken')) return 'Poultry';
    return 'Produce';
  }
}

// ---------------------------------------------------------------------------
// [4] _DescriptionCard
// ---------------------------------------------------------------------------

class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.description, required this.isDark});

  final String description;
  final bool isDark;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(widget.isDark);
    final subTextColor = AppColors.subText(widget.isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(widget.isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.description,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: subTextColor,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.deepGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// [5] _SimilarListingsRow
// ---------------------------------------------------------------------------

class _SimilarListingsRow extends StatelessWidget {
  const _SimilarListingsRow({required this.items, required this.isDark});

  final List<ProductListing> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          return _SimilarCard(
            product: items[i],
            isDark: isDark,
          )
              .animate(delay: (50 * i).ms)
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.04);
        },
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.product, required this.isDark});

  final ProductListing product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.text(isDark);
    final subTextColor = AppColors.subText(isDark);

    return GestureDetector(
      onTap: () =>
          context.push('/marketplace/product/${product.id}'),
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 12),
        decoration: _card(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 148,
                height: 90,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 148,
                  height: 90,
                  color: isDark
                      ? AppColors.cardDark
                      : AppColors.surfaceLight,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 148,
                  height: 90,
                  color: isDark
                      ? AppColors.cardDark
                      : AppColors.surfaceLight,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.gray,
                    size: 28,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatNgn(product.priceNgn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.deepGreen,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.city}, ${product.state}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: subTextColor,
                          fontSize: 10,
                        ),
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

// ---------------------------------------------------------------------------
// Bottom sticky bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.product, required this.isDark});

  final ProductListing product;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final subTextColor = AppColors.subText(isDark);
    final isSoldOut = product.availability == ProductAvailability.soldOut;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E3C2E) : AppColors.borderLight,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Price per kg',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subTextColor,
                    ),
              ),
              Text(
                formatNgn(product.priceNgn),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepGreen,
                    ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Make Offer button
          Expanded(
            child: PrimaryGradientButton(
              label: isSoldOut ? 'Sold Out' : 'Make Offer',
              onPressed: isSoldOut
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sending offer for ${product.title}...',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              icon: isSoldOut ? null : Icons.handshake_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

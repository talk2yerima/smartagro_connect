import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/product_listing.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/empty_state.dart';

final _sellerProfileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, sellerId) =>
      ref.read(firestoreServiceProvider).fetchUserProfile(sellerId),
);

class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(productsProvider);
    final profileAsync = ref.watch(_sellerProfileProvider(sellerId));

    final listings = productsAsync.valueOrNull
            ?.where((p) => p.sellerId == sellerId)
            .toList() ??
        [];

    final profile = profileAsync.valueOrNull;
    final firstListing = listings.isNotEmpty ? listings.first : null;

    // Firestore profile is authoritative; listing fields are the fallback.
    final sellerName =
        (profile?['name'] as String?) ?? firstListing?.sellerName ?? 'Seller';
    final sellerRating = (profile?['rating'] as num?)?.toDouble() ??
        firstListing?.sellerRating ??
        0.0;
    final isVerified =
        (profile?['verified'] as bool?) ?? firstListing?.verified ?? false;
    final location = (profile?['location'] as String?) ??
        (firstListing != null
            ? '${firstListing.city}, ${firstListing.state}'
            : null);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.deepGreen, AppColors.emerald],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    AppAvatar(
                      name: sellerName,
                      color: Colors.white.withValues(alpha: 0.3),
                      radius: 40,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sellerName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.golden),
                        const SizedBox(width: 4),
                        Text(
                          sellerRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (location != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_rounded,
                              size: 14, color: Colors.white70),
                          const SizedBox(width: 2),
                          Text(
                            location,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stats row ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${listings.length}',
                    sublabel: 'Listings',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.star_rounded,
                    label: sellerRating.toStringAsFixed(1),
                    sublabel: 'Rating',
                    isDark: isDark,
                    iconColor: AppColors.golden,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: isVerified
                        ? Icons.verified_rounded
                        : Icons.pending_rounded,
                    label: isVerified ? 'Yes' : 'No',
                    sublabel: 'Verified',
                    isDark: isDark,
                    iconColor: isVerified ? AppColors.infoBlue : AppColors.gray,
                  ),
                ],
              ),
            ),
          ),

          // ── Contact button ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                onPressed: () {
                  final myUid = ref.read(authSessionProvider)?.id ?? '';
                  final ids = [myUid, sellerId]..sort();
                  final threadId = ids.join('_');
                  context.push(
                    '/chat/$threadId'
                    '?name=${Uri.encodeComponent(sellerName)}'
                    '&peerId=$sellerId',
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('Contact Seller'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // ── Listings header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'ACTIVE LISTINGS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
          ),

          // ── Listings grid ─────────────────────────────────────────────────
          productsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.deepGreen),
                ),
              ),
            ),
            error: (_, __) => const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load listings',
                subtitle: 'Pull to refresh and try again.',
              ),
            ),
            data: (_) {
              if (listings.isEmpty) {
                return const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.storefront_rounded,
                    title: 'No active listings',
                    subtitle: 'This seller has no listings at the moment.',
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ListingCard(
                      product: listings[i],
                      isDark: isDark,
                      index: i,
                    ),
                    childCount: listings.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat chip
// ---------------------------------------------------------------------------

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isDark,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool isDark;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.deepGreen),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
              ),
            ),
            Text(
              sublabel,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listing card
// ---------------------------------------------------------------------------

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.product,
    required this.isDark,
    required this.index,
  });

  final ProductListing product;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/marketplace/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
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
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color:
                          isDark ? AppColors.darkTextSecondary : AppColors.gray,
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
      ),
    )
        .animate(delay: (30 * index).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04);
  }
}

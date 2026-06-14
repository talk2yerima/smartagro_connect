import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/sparkline_chart.dart';

// ---------------------------------------------------------------------------
// Local card decoration helper
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
// Category definitions
// ---------------------------------------------------------------------------
const List<String> _categories = [
  'All',
  'Grains',
  'Vegetables',
  'Fruits',
  'Livestock',
  'Oilseeds',
];

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'grains':
      return Icons.grain;
    case 'vegetables':
      return Icons.eco;
    case 'fruits':
      return Icons.spa;
    case 'livestock':
      return Icons.pets;
    case 'oilseeds':
      return Icons.opacity_outlined;
    default:
      return Icons.storefront;
  }
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'grains':
      return const Color(0xFFF9A825);
    case 'vegetables':
      return const Color(0xFF4CAF50);
    case 'fruits':
      return const Color(0xFFFB8C00);
    case 'livestock':
      return const Color(0xFF6D4C41);
    case 'oilseeds':
      return const Color(0xFF0277BD);
    default:
      return const Color(0xFF2E7D32);
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CommodityMarketScreen extends ConsumerStatefulWidget {
  const CommodityMarketScreen({super.key});

  @override
  ConsumerState<CommodityMarketScreen> createState() =>
      _CommodityMarketScreenState();
}

class _CommodityMarketScreenState
    extends ConsumerState<CommodityMarketScreen> {
  String _selectedCategory = 'All';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
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
      if (mounted) setState(() => _query = value);
    });
  }

  List<Commodity> _filtered(List<Commodity> all) {
    var list = all;
    if (_selectedCategory != 'All') {
      list = list
          .where((c) =>
              c.category.toLowerCase() ==
              _selectedCategory.toLowerCase())
          .toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
          .toList();
    }
    return list;
  }

  // Compute summary stats from the full unfiltered list
  _MarketSummary _summary(List<Commodity> all) {
    if (all.isEmpty) {
      return const _MarketSummary(count: 0, avgChange: 0.0);
    }
    final avg =
        all.map((c) => c.changePct).reduce((a, b) => a + b) / all.length;
    return _MarketSummary(count: all.length, avgChange: avg);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(commoditiesProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        title: Text(
          'Market',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.charcoal,
              ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: Icon(
              Icons.search_rounded,
              color:
                  isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
            ),
            tooltip: 'Search',
          ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6, showAvatar: true),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(
              color: AppColors.errorRed,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        data: (items) {
          final filtered = _filtered(items);
          final summary = _summary(items);

          return RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () => ref.refresh(commoditiesProvider.future),
            child: CustomScrollView(
              slivers: [
                // ── 1. Search bar ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SearchBar(
                    controller: _searchController,
                    isDark: isDark,
                    onChanged: _onSearchChanged,
                    onFilterTap: () {
                      // Filter action placeholder — reserved for a bottom sheet
                    },
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04),
                ),

                // ── 2. Category chips ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    selected: _selectedCategory,
                    isDark: isDark,
                    onSelect: (cat) =>
                        setState(() => _selectedCategory = cat),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 60.ms)
                      .slideY(begin: -0.03),
                ),

                // ── 3. Market summary strip ───────────────────────────────
                SliverToBoxAdapter(
                  child: _MarketSummaryStrip(
                    summary: summary,
                    isDark: isDark,
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 100.ms)
                      .slideY(begin: -0.02),
                ),

                // ── 4. Commodity list ─────────────────────────────────────
                filtered.isEmpty
                    ? const SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.bar_chart_rounded,
                          title: 'No commodities found',
                          subtitle:
                              'Try adjusting your search or filters',
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final c = filtered[i];
                              return _CommodityCard(
                                key: ValueKey(c.id),
                                commodity: c,
                                isDark: isDark,
                                index: i,
                              );
                            },
                            findChildIndexCallback: (key) {
                              final id = (key as ValueKey<String>).value;
                              final idx =
                                  filtered.indexWhere((c) => c.id == id);
                              return idx == -1 ? null : idx;
                            },
                            childCount: filtered.length,
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

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
        ),
        decoration: InputDecoration(
          hintText: 'Search commodities…',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.gray,
          ),
          filled: true,
          fillColor:
              isDark ? AppColors.darkSurface : AppColors.surfaceLight,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.gray,
          ),
          suffixIcon: IconButton(
            onPressed: onFilterTap,
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.gray,
            ),
            tooltip: 'Filter',
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.borderLight,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.deepGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chips
// ---------------------------------------------------------------------------
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isActive = selected == cat;
          return GestureDetector(
            key: ValueKey(cat),
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.deepGreen
                    : (isDark
                        ? AppColors.darkSurface
                        : AppColors.surfaceLight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppColors.deepGreen
                      : (isDark
                          ? AppColors.darkBorder
                          : AppColors.borderLight),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Market summary strip
// ---------------------------------------------------------------------------
class _MarketSummary {
  const _MarketSummary({
    required this.count,
    required this.avgChange,
  });

  final int count;
  final double avgChange;
}

class _MarketSummaryStrip extends StatelessWidget {
  const _MarketSummaryStrip({
    required this.summary,
    required this.isDark,
  });

  final _MarketSummary summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final avgUp = summary.avgChange >= 0;
    final avgText =
        '${avgUp ? '+' : ''}${summary.avgChange.toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              size: 8,
              color: AppColors.mintGreen,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${summary.count} commodities live',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            _divider(),
            Text(
              'Avg move: $avgText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: avgUp ? AppColors.mintGreen : const Color(0xFFEF9A9A),
              ),
            ),
            _divider(),
            const Text(
              'Updated 2m ago',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          '|',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Commodity card
// ---------------------------------------------------------------------------
class _CommodityCard extends StatelessWidget {
  const _CommodityCard({
    super.key,
    required this.commodity,
    required this.isDark,
    required this.index,
  });

  final Commodity commodity;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = commodity;
    final isUp = c.changePct >= 0;
    final trendColor =
        isUp ? AppColors.mintGreen : AppColors.errorRed;
    final sparkData = mockSparklineFromChange(c.changePct);
    final catColor = _categoryColor(c.category);
    final catIcon = _categoryIcon(c.category);

    return GestureDetector(
      onTap: () => context.push('/main/market/commodity/${c.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: _card(isDark),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Category icon bubble ───────────────────────────────
            Hero(
              tag: 'commodity-icon-${c.id}',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  catIcon,
                  size: 22,
                  color: catColor,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Name + category ────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${c.category} · ${c.unit}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── Price + trend + sparkline ──────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formatNgn(c.priceNgn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: trendColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${isUp ? '+' : ''}${c.changePct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: trendColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SparklineChart(
                  data: sparkData,
                  color: trendColor,
                  height: 32,
                  width: 68,
                  strokeWidth: 1.6,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      )
          .animate(delay: (60 * index).ms)
          .fadeIn(duration: 280.ms)
          .slideX(begin: -0.03),
    );
  }
}

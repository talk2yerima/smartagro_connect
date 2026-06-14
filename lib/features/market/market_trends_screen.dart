import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/sparkline_chart.dart';

class MarketTrendsScreen extends ConsumerWidget {
  const MarketTrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commoditiesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        title: Text(
          'Market Trends',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: AppColors.text(isDark),
          ),
        ),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 6, height: 88),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.signal_wifi_bad_rounded,
                    size: 48, color: AppColors.errorRed),
                const SizedBox(height: 12),
                Text(
                  'Failed to load market data',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subText(isDark)),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(commoditiesProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (commodities) => _TrendsBody(
          commodities: commodities,
          isDark: isDark,
          onRefresh: () async {
            ref.invalidate(commoditiesProvider);
            await ref.read(commoditiesProvider.future);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _TrendsBody extends StatelessWidget {
  const _TrendsBody({
    required this.commodities,
    required this.isDark,
    required this.onRefresh,
  });

  final List<Commodity> commodities;
  final bool isDark;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final gainers = commodities.where((c) => c.changePct > 0).length;
    final losers = commodities.where((c) => c.changePct < 0).length;
    final avgChange = commodities.isEmpty
        ? 0.0
        : commodities.fold<double>(0, (s, c) => s + c.changePct) /
            commodities.length;

    final sorted = [...commodities]..sort((a, b) => b.changePct.compareTo(a.changePct));
    final topGainers = sorted.take(3).toList();
    final topLosers = sorted.reversed.take(3).toList();

    // Build category averages
    final categoryMap = <String, List<double>>{};
    for (final c in commodities) {
      categoryMap.putIfAbsent(c.category, () => []).add(c.changePct);
    }
    final categoryPerf = categoryMap.entries
        .map((e) => (
              category: e.key,
              avg: e.value.fold<double>(0, (s, v) => s + v) / e.value.length,
            ))
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.deepGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // [1] Summary Card
          _SummaryCard(
            gainers: gainers,
            losers: losers,
            avgChange: avgChange,
            isDark: isDark,
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.04, duration: 350.ms),

          const SizedBox(height: 20),

          // [2] Top Gainers
          const SectionHeader(title: 'Top Gainers ▲'),
          const SizedBox(height: 8),
          ...topGainers.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return _CommodityTrendCard(
              commodity: c,
              isGainer: true,
              isDark: isDark,
            )
                .animate(delay: (80 + 50 * i).ms)
                .fadeIn()
                .slideY(begin: 0.04);
          }),

          const SizedBox(height: 20),

          // [3] Top Losers
          const SectionHeader(title: 'Top Losers ▼'),
          const SizedBox(height: 8),
          ...topLosers.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return _CommodityTrendCard(
              commodity: c,
              isGainer: false,
              isDark: isDark,
            )
                .animate(delay: (80 + 50 * i).ms)
                .fadeIn()
                .slideY(begin: 0.04);
          }),

          const SizedBox(height: 20),

          // [4] Category Performance
          const SectionHeader(title: 'Category Performance'),
          const SizedBox(height: 8),
          _CategoryPerformanceCard(
            categories: categoryPerf
                .map((e) => (category: e.category, avg: e.avg))
                .toList(),
            isDark: isDark,
          )
              .animate(delay: 300.ms)
              .fadeIn()
              .slideY(begin: 0.04),

          const SizedBox(height: 20),

          // [5] Market Insights
          const SectionHeader(title: 'Market Insights'),
          const SizedBox(height: 8),
          const _MarketInsightsCard()
              .animate(delay: 380.ms)
              .fadeIn()
              .slideY(begin: 0.04),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [1] Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.gainers,
    required this.losers,
    required this.avgChange,
    required this.isDark,
  });

  final int gainers;
  final int losers;
  final double avgChange;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final avgUp = avgChange >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppColors.gradientGreen,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331B5E20),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Market Summary',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      avgUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: avgUp ? const Color(0xFF00C853) : const Color(0xFFEF9A9A),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${avgUp ? '+' : ''}${avgChange.toStringAsFixed(1)}% avg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            avgUp ? const Color(0xFF00C853) : const Color(0xFFEF9A9A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Gainers',
                  value: '$gainers',
                  chipColor: const Color(0xFF00C853),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.trending_down_rounded,
                  label: 'Losers',
                  value: '$losers',
                  chipColor: const Color(0xFFEF9A9A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.swap_vert_rounded,
                  label: 'Avg Move',
                  value: '${avgUp ? '+' : ''}${avgChange.toStringAsFixed(1)}%',
                  chipColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.chipColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color chipColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: chipColor,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [2 & 3] Commodity Trend Card
// ─────────────────────────────────────────────────────────────────────────────

class _CommodityTrendCard extends StatelessWidget {
  const _CommodityTrendCard({
    required this.commodity,
    required this.isGainer,
    required this.isDark,
  });

  final Commodity commodity;
  final bool isGainer;
  final bool isDark;

  BoxDecoration _card() {
    return isDark
        ? BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2E3C2E)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2EAE0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final c = commodity;
    final up = c.changePct >= 0;
    final pctColor =
        up ? const Color(0xFF00C853) : const Color(0xFFC62828);
    final sparkColor = up ? const Color(0xFF00C853) : const Color(0xFFC62828);
    final sparkData = mockSparklineFromChange(c.changePct);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card(),
      child: Row(
        children: [
          // Left: icon + category indicator
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isGainer
                      ? const Color(0xFF00C853)
                      : const Color(0xFFC62828))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGainer
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: isGainer
                  ? const Color(0xFF00C853)
                  : const Color(0xFFC62828),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Center: name, price, category
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
                    color: AppColors.text(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatNgn(c.priceNgn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.subText(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${c.category} · ${c.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.subText(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Sparkline
          SparklineChart(
            data: sparkData,
            color: sparkColor,
            height: 36,
            width: 64,
            strokeWidth: 1.8,
            filled: true,
          ),
          const SizedBox(width: 12),
          // % Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: pctColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: pctColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '${up ? '+' : ''}${c.changePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: pctColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [4] Category Performance Card
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryPerformanceCard extends StatelessWidget {
  const _CategoryPerformanceCard({
    required this.categories,
    required this.isDark,
  });

  final List<({String category, double avg})> categories;
  final bool isDark;

  BoxDecoration _card() {
    return isDark
        ? BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2E3C2E)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2EAE0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final maxAbs =
        categories.map((e) => e.avg.abs()).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxAbs == 0 ? 1.0 : maxAbs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final up = cat.avg >= 0;
          final barColor =
              up ? const Color(0xFF00C853) : const Color(0xFFC62828);
          final barFraction = cat.avg.abs() / effectiveMax;

          return Padding(
            padding: EdgeInsets.only(bottom: i < categories.length - 1 ? 14 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text(isDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 11,
                          color: barColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${up ? '+' : ''}${cat.avg.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: barColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: AppColors.surface(isDark),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 6,
                          width: constraints.maxWidth * barFraction,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [5] Market Insights Card
// ─────────────────────────────────────────────────────────────────────────────

class _MarketInsightsCard extends StatelessWidget {
  const _MarketInsightsCard();

  static const _insights = [
    (
      icon: Icons.grain_rounded,
      color: Color(0xFF2E7D32),
      text: 'Maize prices rising due to seasonal demand ahead of planting season',
    ),
    (
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0277BD),
      text: 'Dry-season water scarcity in the north is tightening tomato supply',
    ),
    (
      icon: Icons.local_shipping_rounded,
      color: Color(0xFFFB8C00),
      text: 'Improved Abuja-Kano corridor logistics reducing sorghum transport costs',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E3C2E)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2EAE0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _insights.asMap().entries.map((entry) {
          final i = entry.key;
          final insight = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _insights.length - 1 ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: insight.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.text(isDark),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

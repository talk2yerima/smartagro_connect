import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/sparkline_chart.dart';
import '../../shared/widgets/stat_card.dart';

// ─── Local card decoration helper ────────────────────────────────────────────

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

// ─── Commodity icon helpers (mirror of commodity_market_screen) ───────────────

IconData _commodityIconData(String category) {
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

// ─── Screen ───────────────────────────────────────────────────────────────────

class CommodityDetailScreen extends ConsumerWidget {
  const CommodityDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commoditiesProvider);

    return async.when(
      loading: () => Scaffold(
        appBar: _buildAppBar(context, 'Loading…', null),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(count: 5, height: 100),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: _buildAppBar(context, 'Error', null),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load',
          subtitle: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(commoditiesProvider),
        ),
      ),
      data: (items) {
        final index = items.indexWhere((e) => e.id == id);
        if (index == -1) {
          return Scaffold(
            appBar: _buildAppBar(context, 'Not Found', null),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Commodity not found',
              subtitle:
                  'We could not find a commodity with that ID. It may have been removed.',
            ),
          );
        }

        final c = items[index];
        final related = items
            .where((e) => e.category == c.category && e.id != c.id)
            .take(3)
            .toList();

        return Scaffold(
          backgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBg
                  : AppColors.softWhite,
          appBar: _buildAppBar(context, c.name, c),
          body: RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () async => ref.invalidate(commoditiesProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroPriceCard(commodity: c),
                  const SizedBox(height: 16),
                  _SparklineCard(commodity: c),
                  const SizedBox(height: 16),
                  _MarketStatsGrid(commodity: c),
                  const SizedBox(height: 16),
                  _DetailsCard(commodity: c),
                  const SizedBox(height: 16),
                  _PriceAlertCard(commodity: c),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _RelatedSection(items: related),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    String title,
    Commodity? commodity,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: [
        if (commodity != null)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {
              HapticFeedback.lightImpact();
              final text =
                  '${commodity.name} — ${formatNgn(commodity.priceNgn)} / ${commodity.unit} '
                  '(${commodity.changePct >= 0 ? '+' : ''}${commodity.changePct.toStringAsFixed(2)}%)';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing: $text'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── [1] Hero Price Card ──────────────────────────────────────────────────────

class _HeroPriceCard extends StatelessWidget {
  const _HeroPriceCard({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context) {
    final isUp = commodity.changePct >= 0;
    final trendColor =
        isUp ? AppColors.mintGreen : AppColors.errorRed;
    final signLabel =
        '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category chip + icon hero ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  commodity.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const Spacer(),
              Hero(
                tag: 'commodity-icon-${commodity.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _commodityIconData(commodity.category),
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Price ──
          Text(
            formatNgn(commodity.priceNgn),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Poppins',
                  letterSpacing: -0.5,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // ── Trend badge + unit/origin row ──
          Row(
            children: [
              // Trend badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: trendColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: trendColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      signLabel,
                      style: TextStyle(
                        color: trendColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Unit / origin
              Expanded(
                child: Text(
                  'per ${commodity.unit}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            'Origin: ${_resolveOrigin(commodity)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.96, 0.96),
          duration: 420.ms,
          curve: Curves.easeOut,
        )
        .fadeIn(duration: 380.ms);
  }

  String _resolveOrigin(Commodity c) {
    // Commodity entity has no origin field — derive a plausible one from
    // category so the UI is never blank.
    const map = {
      'Grains': 'Kano, Nigeria',
      'Tubers': 'Benue, Nigeria',
      'Vegetables': 'Plateau, Nigeria',
      'Fruits': 'Ogun, Nigeria',
      'Livestock': 'Sokoto, Nigeria',
      'Poultry': 'Oyo, Nigeria',
      'Fisheries': 'Lagos, Nigeria',
      'Cash Crops': 'Ondo, Nigeria',
    };
    return map[c.category] ?? 'West Africa';
  }
}

// ─── [2] Sparkline Chart Card ─────────────────────────────────────────────────

class _SparklineCard extends StatelessWidget {
  const _SparklineCard({required this.commodity});

  final Commodity commodity;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUp = commodity.changePct >= 0;
    final trendColor = isUp ? AppColors.mintGreen : AppColors.errorRed;
    final sparkData = mockSparklineFromChange(commodity.changePct);

    return Container(
      decoration: _card(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.deepGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.deepGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '7-Day Price Trend',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUp ? 'Uptrend' : 'Downtrend',
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Sparkline ──
          LayoutBuilder(
            builder: (context, constraints) {
              return SparklineChart(
                data: sparkData,
                color: trendColor,
                height: 80,
                width: constraints.maxWidth,
                strokeWidth: 2.2,
                filled: true,
              );
            },
          ),

          const SizedBox(height: 8),

          // ── X-axis day labels ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _dayLabels
                .map(
                  (d) => Text(
                    d,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    )
        .animate(delay: 80.ms)
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, curve: Curves.easeOut);
  }
}

// ─── [3] Market Stats Grid ────────────────────────────────────────────────────

class _MarketStatsGrid extends StatelessWidget {
  const _MarketStatsGrid({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context) {
    final isUp = commodity.changePct >= 0;

    final stats = [
      _StatEntry(
        label: 'Current Price',
        value: formatNgn(commodity.priceNgn),
        icon: Icons.monetization_on_outlined,
        color: AppColors.deepGreen,
        trend: null,
      ),
      _StatEntry(
        label: '7-Day Change',
        value:
            '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(2)}%',
        icon: Icons.trending_up_rounded,
        color: isUp ? AppColors.mintGreen : AppColors.errorRed,
        trend: commodity.changePct,
      ),
      const _StatEntry(
        label: 'Volume',
        value: '2,400',
        icon: Icons.inventory_2_outlined,
        color: AppColors.infoBlue,
        unit: 'MT',
        trend: null,
      ),
      _StatEntry(
        label: 'Market Trend',
        value: isUp ? 'Bullish' : 'Bearish',
        icon: isUp
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        color: isUp ? AppColors.mintGreen : AppColors.errorRed,
        trend: null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Market Statistics',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) {
            final s = stats[i];
            return StatCard(
              label: s.label,
              value: s.value,
              icon: s.icon,
              color: s.color,
              trend: s.trend,
              unit: s.unit,
            ).animate(delay: (50 * i).ms).fadeIn().slideY(begin: 0.04);
          },
        ),
      ],
    );
  }
}

class _StatEntry {
  const _StatEntry({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    this.unit,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
  final String? unit;
}

// ─── [4] Details Card ────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rows = [
      _DetailRow(
          icon: Icons.category_outlined,
          label: 'Category',
          value: commodity.category),
      _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Origin',
          value: _originFor(commodity)),
      _DetailRow(
          icon: Icons.straighten_outlined,
          label: 'Unit',
          value: commodity.unit),
      const _DetailRow(
          icon: Icons.update_rounded,
          label: 'Last Updated',
          value: 'Today, 09:30 AM'),
    ];

    return Container(
      decoration: _card(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.deepGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.deepGreen,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Commodity Details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.charcoal,
                      ),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map(
                (entry) => _buildRow(
                  context,
                  entry.value,
                  isDark,
                  isLast: entry.key == rows.length - 1,
                ),
              ),
        ],
      ),
    )
        .animate(delay: 120.ms)
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, curve: Curves.easeOut);
  }

  Widget _buildRow(
    BuildContext context,
    _DetailRow row,
    bool isDark, {
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                row.icon,
                size: 16,
                color: AppColors.deepGreen.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.gray,
                ),
              ),
              const Spacer(),
              Text(
                row.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? const Color(0xFF2E3C2E)
                : AppColors.borderLight,
          ),
      ],
    );
  }

  String _originFor(Commodity c) {
    const map = {
      'Grains': 'Kano, Nigeria',
      'Tubers': 'Benue, Nigeria',
      'Vegetables': 'Plateau, Nigeria',
      'Fruits': 'Ogun, Nigeria',
      'Livestock': 'Sokoto, Nigeria',
      'Poultry': 'Oyo, Nigeria',
      'Fisheries': 'Lagos, Nigeria',
      'Cash Crops': 'Ondo, Nigeria',
    };
    return map[c.category] ?? 'West Africa';
  }
}

class _DetailRow {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;
}

// ─── [5] Price Alerts Card ────────────────────────────────────────────────────

class _PriceAlertCard extends StatelessWidget {
  const _PriceAlertCard({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet<void>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          backgroundColor:
              isDark ? AppColors.cardDark : Colors.white,
          builder: (_) => _PriceAlertSheet(commodity: commodity),
        );
      },
      child: Container(
        decoration: _card(isDark),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.deepGreen.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.deepGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Price Alert',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Get notified when ${commodity.name} hits your target price',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.gray,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.deepGreen,
              size: 24,
            ),
          ],
        ),
      ),
    )
        .animate(delay: 160.ms)
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, curve: Curves.easeOut);
  }
}

class _PriceAlertSheet extends StatefulWidget {
  const _PriceAlertSheet({required this.commodity});

  final Commodity commodity;

  @override
  State<_PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends State<_PriceAlertSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Set Alert — ${widget.commodity.name}',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Current: ${formatNgn(widget.commodity.priceNgn)} / ${widget.commodity.unit}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.gray,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target price (₦)',
              prefixIcon:
                  const Icon(Icons.monetization_on_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.deepGreen, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Alert set for ${widget.commodity.name} at '
                        '${_controller.text.isEmpty ? '[no price]' : '₦${_controller.text}'}',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text(
                  'Set Alert',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── [6] Related Commodities Section ─────────────────────────────────────────

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({required this.items});

  final List<Commodity> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Related Commodities',
          icon: Icons.grain_rounded,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = items[i];
              return _RelatedCard(commodity: c, index: i);
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.commodity, required this.index});

  final Commodity commodity;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUp = commodity.changePct >= 0;
    final trendColor = isUp ? AppColors.mintGreen : AppColors.errorRed;
    final signLabel =
        '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(1)}%';

    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                CommodityDetailScreen(id: commodity.id),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: _card(isDark),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Name ──
            Text(
              commodity.name,
              maxLines: 2,
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

            // ── Price ──
            Text(
              formatNgn(commodity.priceNgn),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.deepGreen,
              ),
            ),

            // ── Trend row ──
            Row(
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
                  signLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  commodity.unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.gray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      )
          .animate(delay: (50 * index).ms)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.04, curve: Curves.easeOut),
    );
  }
}

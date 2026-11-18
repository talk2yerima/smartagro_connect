import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/money_format.dart';
import '../../domain/entities/commodity.dart';
import '../../domain/entities/price_alert.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_list.dart';
import '../../shared/widgets/sparkline_chart.dart';
import '../../shared/widgets/stat_card.dart';

// ─── Local card decoration helper ────────────────────────────────────────────

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
          subtitle: friendlyError(e),
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
          backgroundColor: Theme.of(context).brightness == Brightness.dark
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
    final trendColor = isUp ? AppColors.mintGreen : AppColors.errorRed;
    final signLabel =
        '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(2)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.deepGreen, AppColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepGreen.withValues(alpha: 0.38),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trendColor.withValues(alpha: 0.5)),
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
            'Category: ${commodity.category}',
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
}

// ─── [2] Sparkline Chart Card ─────────────────────────────────────────────────

class _SparklineCard extends StatelessWidget {
  const _SparklineCard({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUp = commodity.changePct >= 0;
    final trendColor = isUp ? AppColors.mintGreen : AppColors.errorRed;
    final sparkData =
        trendFromChange(commodity.changePct, current: commodity.priceNgn);
    final trendWord = commodity.changePct > 0
        ? 'Rising'
        : commodity.changePct < 0
            ? 'Falling'
            : 'Steady';

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
                'Latest Price Move',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trendWord,
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

          // ── End-point labels: the two real prices behind the line ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              'Previous ${formatNgn(sparkData.first.round())}',
              'Now ${formatNgn(commodity.priceNgn)}',
            ]
                .map(
                  (d) => Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.darkTextSecondary : AppColors.gray,
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
        icon: Icons.sell_outlined,
        color: AppColors.deepGreen,
        trend: null,
      ),
      _StatEntry(
        label: 'Latest Change',
        value: '${isUp ? '+' : ''}${commodity.changePct.toStringAsFixed(2)}%',
        icon: Icons.trending_up_rounded,
        color: isUp ? AppColors.mintGreen : AppColors.errorRed,
        trend: commodity.changePct,
      ),
      // Real field in place of a fixed "2,400 MT" volume shown on every item.
      _StatEntry(
        label: 'Priced per',
        value: commodity.unit,
        icon: Icons.inventory_2_outlined,
        color: AppColors.infoBlue,
        trend: null,
      ),
      _StatEntry(
        label: 'Market Trend',
        value: commodity.changePct > 0
            ? 'Rising'
            : commodity.changePct < 0
                ? 'Falling'
                : 'Steady',
        icon: isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
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
                  color: Theme.of(context).brightness == Brightness.dark
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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
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
      // "Origin" (guessed from category) and "Last Updated" (fixed text,
      // "Today, 09:30 AM") were removed: commodities store neither. Add them
      // back when the price feed provides a source region and timestamp.
      _DetailRow(
          icon: Icons.straighten_outlined,
          label: 'Unit',
          value: commodity.unit),
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
                  color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
                ),
              ),
              const Spacer(),
              Text(
                row.value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
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
            color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          ),
      ],
    );
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

/// "Set Price Alert" plus the person's alerts for this commodity. Alerts are
/// saved to Firestore; the backend notifies once when a price change crosses
/// the target, then marks the alert as used.
class _PriceAlertCard extends ConsumerWidget {
  const _PriceAlertCard({required this.commodity});

  final Commodity commodity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alerts =
        ref.watch(priceAlertsProvider(commodity.id)).valueOrNull ?? const [];
    final accent = isDark ? AppColors.lightGreen : AppColors.deepGreen;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border_(isDark)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(Icons.notifications_active_outlined, color: accent),
            ),
            title: const Text('Set Price Alert',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                Text('Get notified when ${commodity.name} reaches your price'),
            trailing: Icon(Icons.chevron_right_rounded, color: accent),
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _PriceAlertSheet(commodity: commodity),
              );
            },
          ),
          for (final a in alerts) ...[
            Divider(height: 1, color: AppColors.border_(isDark)),
            ListTile(
              dense: true,
              leading: Icon(
                a.above
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: a.active ? accent : AppColors.subText(isDark),
              ),
              title: Text(
                '${a.above ? 'Rises above' : 'Falls below'} '
                '${formatNgn(a.targetNgn)}',
                style: TextStyle(
                  decoration: a.active ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(a.active ? 'Waiting' : 'Reached. You were told.'),
              trailing: IconButton(
                tooltip: 'Remove alert',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => ref
                    .read(firestoreServiceProvider)
                    .deletePriceAlert(a.id)
                    .catchError((Object e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyError(e))));
                  }
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceAlertSheet extends ConsumerStatefulWidget {
  const _PriceAlertSheet({required this.commodity});

  final Commodity commodity;

  @override
  ConsumerState<_PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends ConsumerState<_PriceAlertSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  int? get _target => int.tryParse(_controller.text.trim());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = widget.commodity;
    final target = _target;
    final uid = ref.read(authSessionProvider)?.id;
    if (target == null || target <= 0) {
      setState(() => _error = 'Enter a price in naira, for example 30000.');
      return;
    }
    if (target == c.priceNgn) {
      setState(() => _error = "That's today's price. Choose a higher or "
          'lower price to be told about.');
      return;
    }
    if (uid == null) return;
    final above = PriceAlert.directionFor(target: target, current: c.priceNgn);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(firestoreServiceProvider).createPriceAlert(
            uid: uid,
            commodityId: c.id,
            commodityName: c.name,
            unit: c.unit,
            targetNgn: target,
            above: above,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Alert set. We'll tell you when ${c.name} "
            '${above ? 'rises above' : 'falls below'} ${formatNgn(target)}.'),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.commodity;
    final target = _target;
    final hint = target == null || target <= 0 || target == c.priceNgn
        ? null
        : PriceAlert.directionFor(target: target, current: c.priceNgn)
            ? "You'll be told when it rises to ${formatNgn(target)} or more."
            : "You'll be told when it falls to ${formatNgn(target)} or less.";

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Price alert: ${c.name}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Today: ${formatNgn(c.priceNgn)} per ${c.unit}'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'Tell me when the price reaches (₦)',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(_saving ? 'Saving…' : 'Set alert'),
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
            builder: (_) => CommodityDetailScreen(id: commodity.id),
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
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
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

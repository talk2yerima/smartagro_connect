import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/firestore_providers.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final _adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(firestoreServiceProvider).fetchAdminStats();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(_adminStatsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Platform Analytics',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_adminStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.deepGreen)),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: AppColors.gray),
              const SizedBox(height: 12),
              const Text('Could not load analytics.',
                  style: TextStyle(color: AppColors.gray)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(_adminStatsProvider),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepGreen),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (stats) => _AnalyticsBody(stats: stats, isDark: isDark),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.stats, required this.isDark});

  final Map<String, dynamic> stats;
  final bool isDark;

  String _shortNgn(double v) {
    if (v >= 1e9) return '₦${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '₦${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '₦${(v / 1e3).toStringAsFixed(1)}K';
    return '₦${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final total = stats['totalUsers'] as int? ?? 0;
    final farmers = stats['farmers'] as int? ?? 0;
    final buyers = stats['buyers'] as int? ?? 0;
    final transporters = stats['transporters'] as int? ?? 0;
    final verified = stats['verified'] as int? ?? 0;
    final listings = stats['totalListings'] as int? ?? 0;
    final gmv = stats['gmvNgn'] as double? ?? 0;

    final kpis = [
      (
        label: 'Total Users',
        value: '$total',
        icon: Icons.people_outline,
        color: AppColors.infoBlue
      ),
      (
        label: 'Active Listings',
        value: '$listings',
        icon: Icons.storefront_outlined,
        color: AppColors.golden
      ),
      (
        label: 'Est. GMV',
        value: _shortNgn(gmv),
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.deepGreen
      ),
      (
        label: 'Verified Users',
        value: '$verified',
        icon: Icons.verified_outlined,
        color: AppColors.mintGreen
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── KPI grid ─────────────────────────────────────────────────────────
        const SectionHeader(title: 'Summary', icon: Icons.dashboard_outlined),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: List.generate(kpis.length, (i) {
            final k = kpis[i];
            return StatCard(
              label: k.label,
              value: k.value,
              icon: k.icon,
              color: k.color,
            )
                .animate(delay: (50 * i).ms)
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.04, end: 0, duration: 300.ms);
          }),
        ),

        const SizedBox(height: 24),

        // ── User role breakdown ───────────────────────────────────────────────
        const SectionHeader(
            title: 'User Breakdown', icon: Icons.people_alt_outlined),
        const SizedBox(height: 10),
        _BreakdownCard(
          isDark: isDark,
          total: total,
          rows: [
            _Row('Farmers', farmers, AppColors.freshGreen,
                Icons.agriculture_outlined),
            _Row('Buyers', buyers, AppColors.infoBlue,
                Icons.shopping_cart_outlined),
            _Row('Transporters', transporters, AppColors.warmOrange,
                Icons.local_shipping_outlined),
          ],
        )
            .animate(delay: 250.ms)
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.04, end: 0, duration: 300.ms),

        const SizedBox(height: 24),

        // ── Marketplace health ────────────────────────────────────────────────
        const SectionHeader(
            title: 'Marketplace Health', icon: Icons.monitor_heart_outlined),
        const SizedBox(height: 10),
        _HealthCard(
          isDark: isDark,
          rows: [
            (label: 'Registered users', value: '$total', ok: true),
            (label: 'Active listings', value: '$listings', ok: true),
            (label: 'Verified sellers', value: '$verified', ok: verified > 0),
            (label: 'Farmers onboarded', value: '$farmers', ok: farmers > 0),
            (label: 'Buyers registered', value: '$buyers', ok: buyers > 0),
          ],
        )
            .animate(delay: 350.ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.04, end: 0, duration: 350.ms),
      ],
    );
  }
}

// ─── Role breakdown card ──────────────────────────────────────────────────────

class _Row {
  const _Row(this.label, this.count, this.color, this.icon);
  final String label;
  final int count;
  final Color color;
  final IconData icon;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard(
      {required this.isDark, required this.total, required this.rows});

  final bool isDark;
  final int total;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: rows.map((r) {
          final fraction = total > 0 ? r.count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.icon, size: 14, color: r.color),
                    const SizedBox(width: 6),
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : AppColors.charcoal,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${r.count}  (${(fraction * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: r.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.toDouble(),
                    minHeight: 6,
                    backgroundColor: r.color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(r.color),
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

// ─── Health card ──────────────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.isDark, required this.rows});

  final bool isDark;
  final List<({String label, String value, bool ok})> rows;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final r = rows[i];
          final dot = r.ok ? AppColors.mintGreen : AppColors.warmOrange;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < rows.length - 1)
                Divider(
                    height: 1, indent: 36, endIndent: 16, color: borderColor),
            ],
          );
        }),
      ),
    );
  }
}

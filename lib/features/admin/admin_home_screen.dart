import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';

// ─── Card box decoration helper ─────────────────────────────────────────────

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

// ─── Mock data ───────────────────────────────────────────────────────────────

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;
}

const _activities = <_ActivityItem>[
  _ActivityItem(
    icon: Icons.person_add_alt_1_outlined,
    title: 'New user registered',
    subtitle: 'Amara Okonkwo joined as Farmer',
    time: '2 min ago',
    color: AppColors.infoBlue,
  ),
  _ActivityItem(
    icon: Icons.flag_outlined,
    title: 'Listing flagged',
    subtitle: 'Maize lot #1042 reported for pricing',
    time: '14 min ago',
    color: AppColors.warmOrange,
  ),
  _ActivityItem(
    icon: Icons.handshake_outlined,
    title: 'Trade completed',
    subtitle: '12 bags of cassava — ₦84,000 settled',
    time: '1 hr ago',
    color: AppColors.freshGreen,
  ),
  _ActivityItem(
    icon: Icons.person_add_alt_1_outlined,
    title: 'New user registered',
    subtitle: 'Emeka Adeyemi joined as Buyer',
    time: '2 hr ago',
    color: AppColors.infoBlue,
  ),
  _ActivityItem(
    icon: Icons.edit_note_outlined,
    title: 'Listing approved',
    subtitle: 'Yam lot #1038 cleared by moderator',
    time: '3 hr ago',
    color: AppColors.emerald,
  ),
];

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Color color;
}

const _quickActions = <_QuickAction>[
  _QuickAction(
    icon: Icons.people_outline,
    label: 'Users',
    subtitle: 'Manage accounts',
    route: '/admin/users',
    color: AppColors.infoBlue,
  ),
  _QuickAction(
    icon: Icons.gavel_outlined,
    label: 'Moderation',
    subtitle: 'Review flagged items',
    route: '/admin/moderation',
    color: AppColors.warmOrange,
  ),
  _QuickAction(
    icon: Icons.bar_chart,
    label: 'Commodities',
    subtitle: 'Prices & catalog',
    route: '/admin/commodities',
    color: AppColors.emerald,
  ),
  _QuickAction(
    icon: Icons.analytics_outlined,
    label: 'Analytics',
    subtitle: 'Platform insights',
    route: '/admin/analytics',
    color: AppColors.golden,
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  DateTime _lastRefreshed = DateTime.now();

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _lastRefreshed = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.softWhite;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        title: const Text(
          'Admin Console',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              backgroundColor: AppColors.warmOrange,
              smallSize: 8,
              child: Icon(
                Icons.notifications_outlined,
                color: isDark ? Colors.white : AppColors.charcoal,
              ),
            ),
            tooltip: 'Notifications',
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.deepGreen,
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── [1] Welcome Banner ────────────────────────────────────────
            _WelcomeBanner(lastRefreshed: _lastRefreshed)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.04),

            const SizedBox(height: 20),

            // ── [2] KPI Grid ──────────────────────────────────────────────
            const SectionHeader(
              title: 'Platform KPIs',
              icon: Icons.dashboard_outlined,
            ),
            const SizedBox(height: 10),
            _KpiGrid(isDark: isDark),

            const SizedBox(height: 20),

            // ── [3] Quick Actions ─────────────────────────────────────────
            const SectionHeader(
              title: 'Quick Actions',
              icon: Icons.flash_on_outlined,
            ),
            const SizedBox(height: 10),
            _QuickActionsGrid(isDark: isDark),

            const SizedBox(height: 20),

            // ── [4] Recent Activity ───────────────────────────────────────
            const SectionHeader(
              title: 'Recent Activity',
              icon: Icons.history_outlined,
              actionLabel: 'View all',
            ),
            const SizedBox(height: 10),
            _ActivityFeed(isDark: isDark),

            const SizedBox(height: 20),

            // ── [5] System Status ─────────────────────────────────────────
            const SectionHeader(
              title: 'System Status',
              icon: Icons.monitor_heart_outlined,
            ),
            const SizedBox(height: 10),
            _SystemStatusCard(isDark: isDark)
                .animate(delay: 200.ms)
                .fadeIn()
                .slideY(begin: 0.04),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── [1] Welcome Banner ───────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.lastRefreshed});

  final DateTime lastRefreshed;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, h:mm a').format(lastRefreshed);

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepGreen.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.white, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Platform Overview',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: 'Platform Online  ✓',
                color: AppColors.mintGreen,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last refreshed: $timeStr',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _BannerStat(label: 'Uptime', value: '99.8%'),
              SizedBox(width: 24),
              _BannerStat(label: 'Active Users', value: '312'),
              SizedBox(width: 24),
              _BannerStat(label: 'Open Tickets', value: '7'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.72),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── [2] KPI Grid ─────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const kpis = [
      (
        label: 'Total Users',
        value: '1,247',
        icon: Icons.people_outline,
        color: AppColors.infoBlue,
        trend: 4.2,
      ),
      (
        label: 'Active Listings',
        value: '342',
        icon: Icons.storefront_outlined,
        color: AppColors.freshGreen,
        trend: 1.8,
      ),
      (
        label: 'Trades This Week',
        value: '89',
        icon: Icons.swap_horiz_rounded,
        color: AppColors.golden,
        trend: -2.1,
      ),
      (
        label: 'Revenue',
        value: '₦2.4M',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.warmOrange,
        trend: 7.5,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: List.generate(kpis.length, (i) {
        final kpi = kpis[i];
        return StatCard(
          label: kpi.label,
          value: kpi.value,
          icon: kpi.icon,
          color: kpi.color,
          trend: kpi.trend,
        )
            .animate(delay: (50 * i).ms)
            .fadeIn()
            .slideY(begin: 0.04);
      }),
    );
  }
}

// ─── [3] Quick Actions Grid ───────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(_quickActions.length, (i) {
        final action = _quickActions[i];
        return _QuickActionCard(action: action, isDark: isDark)
            .animate(delay: (50 * i).ms)
            .fadeIn()
            .slideY(begin: 0.04);
      }),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.isDark});

  final _QuickAction action;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(action.route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: _card(isDark),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.gray,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── [4] Activity Feed ────────────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(isDark),
      child: Column(
        children: List.generate(_activities.length, (i) {
          final item = _activities[i];
          final isLast = i == _activities.length - 1;
          return _ActivityRow(
            item: item,
            isDark: isDark,
            showDivider: !isLast,
          )
              .animate(delay: (50 * i).ms)
              .fadeIn()
              .slideY(begin: 0.04);
        }),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.isDark,
    required this.showDivider,
  });

  final _ActivityItem item;
  final bool isDark;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : AppColors.charcoal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.time,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.gray,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: isDark
                ? const Color(0xFF2E3C2E)
                : const Color(0xFFE2EAE0),
          ),
      ],
    );
  }
}

// ─── [5] System Status Card ───────────────────────────────────────────────────

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(
            label: 'API',
            status: 'Operational',
            statusColor: AppColors.mintGreen,
            icon: Icons.cloud_done_outlined,
            isDark: isDark,
            showDivider: true,
          ),
          _StatusRow(
            label: 'Database',
            status: 'Operational',
            statusColor: AppColors.mintGreen,
            icon: Icons.storage_outlined,
            isDark: isDark,
            showDivider: true,
          ),
          _StatusRow(
            label: 'Push Notifications',
            status: 'Degraded',
            statusColor: AppColors.warmOrange,
            icon: Icons.notifications_active_outlined,
            isDark: isDark,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.isDark,
    required this.showDivider,
  });

  final String label;
  final String status;
  final Color statusColor;
  final IconData icon;
  final bool isDark;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isDark ? AppColors.gray : AppColors.gray,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: status,
                color: statusColor,
                icon: statusColor == AppColors.mintGreen
                    ? Icons.check_circle_outline
                    : Icons.circle,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: isDark
                ? const Color(0xFF2E3C2E)
                : const Color(0xFFE2EAE0),
          ),
      ],
    );
  }
}

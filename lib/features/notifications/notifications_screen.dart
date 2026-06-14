import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/app_notification.dart';
import '../../shared/widgets/empty_state.dart';

// ── Local card decoration helper ─────────────────────────────────────────────
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

// ── Notification type config ──────────────────────────────────────────────────
class _TypeConfig {
  const _TypeConfig({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

const Map<String, _TypeConfig> _typeConfigs = {
  'price_alert': _TypeConfig(
    icon: Icons.show_chart_rounded,
    color: AppColors.golden,
  ),
  'new_buyer': _TypeConfig(
    icon: Icons.person_add_outlined,
    color: AppColors.infoBlue,
  ),
  'order': _TypeConfig(
    icon: Icons.inventory_2_outlined,
    color: AppColors.deepGreen,
  ),
  'system': _TypeConfig(
    icon: Icons.info_outline,
    color: AppColors.gray,
  ),
};

_TypeConfig _configFor(String type) =>
    _typeConfigs[type] ??
    const _TypeConfig(icon: Icons.notifications_outlined, color: AppColors.gray);

// ── Mutable notification model (wraps entity with local read state) ───────────
class _MutableNotification {
  _MutableNotification({required this.notification, required this.read});
  final AppNotification notification;
  bool read;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<_MutableNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _buildMocks();
  }

  // ── Mock data ───────────────────────────────────────────────────────────────
  List<_MutableNotification> _buildMocks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final earlier = today.subtract(const Duration(days: 5));

    final items = <AppNotification>[
      AppNotification(
        id: 'n1',
        type: 'price_alert',
        title: 'Maize Price Surge',
        body: 'Maize (white) jumped +4.2% in Kano corridor — now ₦58,000/tonne.',
        createdAt: today.add(const Duration(hours: 9, minutes: 15)),
        read: false,
      ),
      AppNotification(
        id: 'n2',
        type: 'new_buyer',
        title: 'New Buyer Request',
        body: 'Lagos Commodity Hub is seeking 200 bags of yellow maize for next-week delivery.',
        createdAt: today.add(const Duration(hours: 7, minutes: 42)),
        read: false,
      ),
      AppNotification(
        id: 'n3',
        type: 'order',
        title: 'Order #AG-0041 Confirmed',
        body: 'Your soybean shipment to Abuja has been confirmed by the transporter.',
        createdAt: today.add(const Duration(hours: 6)),
        read: true,
      ),
      AppNotification(
        id: 'n4',
        type: 'system',
        title: 'Profile Verification Complete',
        body: 'Your seller identity and farm documents have been verified successfully.',
        createdAt: today.add(const Duration(hours: 2, minutes: 5)),
        read: true,
      ),
      AppNotification(
        id: 'n5',
        type: 'price_alert',
        title: 'Sorghum Price Drop',
        body: 'Red sorghum fell -2.8% in Plateau state — review your listing price.',
        createdAt: yesterday.add(const Duration(hours: 14, minutes: 30)),
        read: false,
      ),
      AppNotification(
        id: 'n6',
        type: 'new_buyer',
        title: 'Repeat Buyer Interest',
        body: 'EcoHarvest Foods (trusted buyer) is interested in your cassava listing.',
        createdAt: yesterday.add(const Duration(hours: 10)),
        read: false,
      ),
      AppNotification(
        id: 'n7',
        type: 'order',
        title: 'Order #AG-0038 Delivered',
        body: 'Your 50-bag groundnut order has been delivered and payment released.',
        createdAt: earlier.add(const Duration(hours: 16)),
        read: true,
      ),
      AppNotification(
        id: 'n8',
        type: 'system',
        title: 'App Update Available',
        body: 'SmartAgro Connect v2.1 is ready — includes improved price charts and offline mode.',
        createdAt: earlier.add(const Duration(hours: 8, minutes: 20)),
        read: true,
      ),
    ];

    return items
        .map((n) => _MutableNotification(notification: n, read: n.read))
        .toList();
  }

  // ── Grouping helpers ────────────────────────────────────────────────────────
  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
  }

  String _groupLabel(DateTime dt) {
    if (_isToday(dt)) return 'Today';
    if (_isYesterday(dt)) return 'Yesterday';
    return 'Earlier';
  }

  // Returns groups in order: Today, Yesterday, Earlier (only non-empty groups)
  List<MapEntry<String, List<_MutableNotification>>> _grouped() {
    final map = <String, List<_MutableNotification>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };
    for (final n in _notifications) {
      map[_groupLabel(n.notification.createdAt)]!.add(n);
    }
    return map.entries.where((e) => e.value.isNotEmpty).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
    });
  }

  void _markRead(String id) {
    setState(() {
      final item = _notifications.firstWhere((n) => n.notification.id == id);
      item.read = true;
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _notifications = _buildMocks();
    });
  }

  // ── Timestamp formatting ────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:$min $period';
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final hasAny = _notifications.isNotEmpty;
    final groups = _grouped();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
          ),
        ),
        actions: [
          if (hasAny)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.emerald,
                ),
              ),
            ),
        ],
      ),
      body: hasAny
          ? RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.emerald,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _countItems(groups),
                itemBuilder: (context, index) =>
                    _buildItem(context, index, groups, isDark, textTheme),
              ),
            )
          : const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: "All caught up!",
              subtitle: "You have no notifications right now.\nCheck back later for updates.",
            ),
    );
  }

  // ── Item count (headers + tiles) ────────────────────────────────────────────
  int _countItems(
      List<MapEntry<String, List<_MutableNotification>>> groups) {
    int count = 0;
    for (final g in groups) {
      count += 1 + g.value.length; // 1 header + N tiles
    }
    return count;
  }

  // ── Flat index -> group/tile resolver ────────────────────────────────────────
  Widget _buildItem(
    BuildContext context,
    int index,
    List<MapEntry<String, List<_MutableNotification>>> groups,
    bool isDark,
    TextTheme textTheme,
  ) {
    int cursor = 0;
    int animIndex = 0;

    for (final entry in groups) {
      if (index == cursor) {
        // Day header
        return _DayHeader(label: entry.key, isDark: isDark, textTheme: textTheme)
            .animate(delay: (40 * animIndex).ms)
            .fadeIn();
      }
      cursor++;
      animIndex++;

      for (final n in entry.value) {
        if (index == cursor) {
          return _NotificationTile(
            item: n,
            isDark: isDark,
            textTheme: textTheme,
            animIndex: animIndex,
            formatTime: _formatTime,
            onTap: () => _markRead(n.notification.id),
          );
        }
        cursor++;
        animIndex++;
      }
    }

    return const SizedBox.shrink();
  }
}

// ── Day Header Widget ─────────────────────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.isDark,
    required this.textTheme,
  });

  final String label;
  final bool isDark;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: AppColors.gray,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Notification Tile Widget ──────────────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.textTheme,
    required this.animIndex,
    required this.formatTime,
    required this.onTap,
  });

  final _MutableNotification item;
  final bool isDark;
  final TextTheme textTheme;
  final int animIndex;
  final String Function(DateTime) formatTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = item.notification;
    final config = _configFor(n.type);
    final isUnread = !item.read;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: _card(isDark),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type icon circle ──────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.icon,
                  size: 20,
                  color: config.color,
                ),
              ),
              const SizedBox(width: 12),

              // ── Text content ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.gray,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatTime(n.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.gray,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Unread dot ────────────────────────────────────────────────
              if (isUnread) ...[
                const SizedBox(width: 10),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.infoBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate(delay: (40 * animIndex).ms)
        .fadeIn(duration: 280.ms);
  }
}

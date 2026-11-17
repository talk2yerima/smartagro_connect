import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../../shared/widgets/empty_state.dart';

// ── Type config ───────────────────────────────────────────────────────────────

class _TypeConfig {
  const _TypeConfig({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

const Map<String, _TypeConfig> _typeConfigs = {
  'price_alert':
      _TypeConfig(icon: Icons.show_chart_rounded, color: AppColors.golden),
  'new_buyer':
      _TypeConfig(icon: Icons.person_add_outlined, color: AppColors.infoBlue),
  'order':
      _TypeConfig(icon: Icons.inventory_2_outlined, color: AppColors.deepGreen),
  'system': _TypeConfig(icon: Icons.info_outline, color: AppColors.gray),
};

_TypeConfig _configFor(String type) =>
    _typeConfigs[type] ??
    const _TypeConfig(
        icon: Icons.notifications_outlined, color: AppColors.gray);

// ── Mutable wrapper ───────────────────────────────────────────────────────────

class _MutableNotification {
  _MutableNotification({required this.notification, required this.read});
  final AppNotification notification;
  bool read;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<_MutableNotification> _items = [];
  final Set<String> _localRead = {};

  // ── Sync stream → local list ──────────────────────────────────────────────

  void _syncFromStream(List<AppNotification> incoming) {
    _items = incoming.map((n) {
      final read = _localRead.contains(n.id) || n.read;
      return _MutableNotification(notification: n, read: read);
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _markRead(String id) async {
    setState(() {
      _localRead.add(id);
      for (final n in _items) {
        if (n.notification.id == id) n.read = true;
      }
    });
    final uid = ref.read(authSessionProvider)?.id;
    if (uid != null) {
      await ref.read(firestoreServiceProvider).markNotificationRead(uid, id);
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _items) {
        _localRead.add(n.notification.id);
        n.read = true;
      }
    });
    final uid = ref.read(authSessionProvider)?.id;
    if (uid != null) {
      await ref.read(firestoreServiceProvider).markAllNotificationsRead(uid);
    }
  }

  // ── Grouping ───────────────────────────────────────────────────────────────

  String _groupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return 'Earlier';
  }

  List<MapEntry<String, List<_MutableNotification>>> _grouped() {
    final map = <String, List<_MutableNotification>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };
    for (final n in _items) {
      map[_groupLabel(n.notification.createdAt)]!.add(n);
    }
    return map.entries.where((e) => e.value.isNotEmpty).toList();
  }

  // ── Time format ────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:$min $period';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    // Re-sync whenever the stream emits a new list.
    ref.listen<AsyncValue<List<AppNotification>>>(
      notificationsProvider,
      (_, next) => next.whenData(
        (data) {
          if (mounted) setState(() => _syncFromStream(data));
        },
      ),
    );

    // Seed on first build (stream may already have data synchronously).
    final streamValue = ref.watch(notificationsProvider);
    if (_items.isEmpty) {
      streamValue.whenData(_syncFromStream);
    }

    final groups = _grouped();
    final hasAny = _items.isNotEmpty;
    final loading = streamValue.isLoading && _items.isEmpty;

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
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.deepGreen))
          : !hasAny
              ? const EmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'All caught up!',
                  subtitle:
                      'You have no notifications right now.\nCheck back later for updates.',
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  color: AppColors.emerald,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _countItems(groups),
                    itemBuilder: (ctx, i) =>
                        _buildItem(ctx, i, groups, isDark, textTheme),
                  ),
                ),
    );
  }

  // ── List helpers ───────────────────────────────────────────────────────────

  int _countItems(List<MapEntry<String, List<_MutableNotification>>> groups) {
    int count = 0;
    for (final g in groups) {
      count += 1 + g.value.length;
    }
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    List<MapEntry<String, List<_MutableNotification>>> groups,
    bool isDark,
    TextTheme textTheme,
  ) {
    int cursor = 0, animIndex = 0;
    for (final entry in groups) {
      if (index == cursor) {
        return _DayHeader(
                label: entry.key, isDark: isDark, textTheme: textTheme)
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

// ── Day Header ────────────────────────────────────────────────────────────────

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

// ── Notification Tile ─────────────────────────────────────────────────────────

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
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark
                  ? AppColors.deepGreen.withValues(alpha: 0.08)
                  : AppColors.deepGreen.withValues(alpha: 0.04))
              : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? AppColors.deepGreen.withValues(alpha: 0.20)
                : borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon bubble
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(config.icon, size: 20, color: config.color),
              ),
              const SizedBox(width: 12),
              // Text
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
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.gray, height: 1.45),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatTime(n.createdAt),
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.gray, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Unread dot
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
    ).animate(delay: (40 * animIndex).ms).fadeIn(duration: 280.ms);
  }
}

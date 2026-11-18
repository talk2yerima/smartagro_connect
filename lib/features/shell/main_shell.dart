import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/services/push_messaging_service.dart';
import '../../domain/entities/app_user.dart';
import '../delivery/driver_tracker.dart';

// ---------------------------------------------------------------------------
// MainShell
// ---------------------------------------------------------------------------

/// Persistent bottom-navigation shell wrapping [StatefulNavigationShell].
///
/// Roles:
///   farmer / buyer  → Home | Market        | Messages | Profile
///   transporter     → Home | Routes (map)  | Messages | Profile
///   admin           → Home | Market        | Listings | Profile
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupFcm());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Silently verify any payment references the user completed in the browser.
      ref.read(transactionRefQueueProvider).drainPendingRefs();
    }
  }

  void _setupFcm() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return;

    final push = PushMessagingService.instance;

    push.onForegroundMessage = (RemoteMessage message) {
      if (!mounted) return;
      final title = message.notification?.title ?? 'New notification';
      final body = message.notification?.body;
      final route = message.data['route'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (body != null) Text(body, maxLines: 2),
            ],
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: route != null
              ? SnackBarAction(
                  label: 'View',
                  onPressed: () => context.push(route),
                )
              : null,
        ),
      );
    };

    push.onNotificationTap = (RemoteMessage message) {
      if (!mounted) return;
      final route = message.data['route'] as String?;
      if (route != null) context.push(route);
    };

    push.onTokenRefresh = _persistFcmToken;

    final initialToken = push.fcmToken;
    if (initialToken != null) _persistFcmToken(initialToken);
  }

  void _persistFcmToken(String token) {
    final uid = ref.read(authSessionProvider)?.id;
    if (uid == null) return;
    ref.read(firestoreServiceProvider).saveFcmToken(uid, token);
  }

  @override
  void didUpdateWidget(MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.navigationShell.currentIndex;
      });
    }
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    if (index == _currentIndex) {
      // Already on this branch — pop back to root of branch.
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    setState(() => _currentIndex = index);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authSessionProvider)?.role ?? UserRole.farmer;
    // Transporters: keep sharing location on a delivery under way, across
    // every screen (starts and stops by itself).
    if (role == UserRole.transporter) ref.watch(driverTrackerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destinations = _buildDestinations(role, isDark);

    // Total unread count for the Messages badge
    final totalUnread = ref
            .watch(chatThreadsProvider)
            .whenData(
              (threads) => threads.fold<int>(0, (sum, t) => sum + t.unread),
            )
            .valueOrNull ??
        0;
    if (totalUnread > 0) {
      destinations[2] = _NavDestination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
        badgeCount: totalUnread,
      );
    }

    final showFab = role == UserRole.farmer && _currentIndex != 2;
    final useRail = MediaQuery.sizeOf(context).width >= 600;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            _NavRail(
              currentIndex: _currentIndex,
              destinations: destinations,
              onTap: _onTap,
              isDark: isDark,
              showFab: showFab,
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.navigationShell,
      // FAB for farmers — quick-add listing.
      floatingActionButton: showFab ? _FarmerFab(isDark: isDark) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        destinations: destinations,
        onTap: _onTap,
        isDark: isDark,
      ),
    );
  }

  List<_NavDestination> _buildDestinations(UserRole role, bool isDark) {
    return [
      const _NavDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _tab1Destination(role),
      const _NavDestination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        activeIcon: Icons.chat_bubble_rounded,
      ),
      const _NavDestination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];
  }

  _NavDestination _tab1Destination(UserRole role) {
    return switch (role) {
      UserRole.transporter => const _NavDestination(
          label: 'Jobs',
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
        ),
      UserRole.admin => const _NavDestination(
          label: 'Listings',
          icon: Icons.list_alt_outlined,
          activeIcon: Icons.list_alt_rounded,
        ),
      _ => const _NavDestination(
          label: 'Market',
          icon: Icons.candlestick_chart_outlined,
          activeIcon: Icons.candlestick_chart_rounded,
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation bar widget
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    required this.isDark,
  });

  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;
  final bool isDark;

  static const _indicatorColor = Color(0xFFE8F5E9); // very light green pill
  static const _indicatorColorDark = Color(0xFF1E3A1E);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    // Deep green on the dark bar was ~2:1 contrast; use the light green there.
    final selectedColor = isDark ? AppColors.lightGreen : AppColors.deepGreen;
    final unselectedColor =
        isDark ? AppColors.darkTextSecondary : AppColors.gray;
    // Grow with the phone's text size so labels don't clip at large fonts.
    final barHeight =
        72 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: List.generate(destinations.length, (i) {
              return Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  isSelected: i == currentIndex,
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  indicatorColor:
                      isDark ? _indicatorColorDark : _indicatorColor,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual nav item
// ---------------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.indicatorColor,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final Color indicatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? selectedColor : unselectedColor;

    // Tells screen readers this is a tab and which one is selected.
    return Semantics(
      button: true,
      selected: isSelected,
      child: _buildTap(color),
    );
  }

  Widget _buildTap(Color color) {
    return InkWell(
      onTap: onTap,
      splashColor: selectedColor.withValues(alpha: 0.10),
      highlightColor: selectedColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? indicatorColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Badge(
              isLabelVisible: destination.badgeCount > 0,
              label: Text(
                destination.badgeCount > 99
                    ? '99+'
                    : '${destination.badgeCount}',
                style: const TextStyle(fontSize: 9),
              ),
              backgroundColor: Colors.red.shade600,
              child: Icon(
                isSelected ? destination.activeIcon : destination.icon,
                size: 22,
                color: color,
              ),
            )
                .animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(0.88, 0.88),
                  end: const Offset(1.0, 1.0),
                  duration: 200.ms,
                  curve: Curves.easeOutBack,
                )
                .slideY(
                  begin: 0.18,
                  end: 0.0,
                  duration: 200.ms,
                  curve: Curves.easeOutBack,
                ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 0.1,
            ),
            child: Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer FAB
// ---------------------------------------------------------------------------

class _FarmerFab extends StatelessWidget {
  const _FarmerFab({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => context.push('/marketplace/add'),
      elevation: 4,
      backgroundColor: AppColors.warmOrange, // warmOrange
      foregroundColor: Colors.white,
      tooltip: 'Add Listing',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add_rounded, size: 28),
    )
        .animate()
        .scale(
          begin: const Offset(0.0, 0.0),
          end: const Offset(1.0, 1.0),
          delay: 300.ms,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(delay: 300.ms, duration: 300.ms);
  }
}

// ---------------------------------------------------------------------------
// Navigation rail (tablets ≥ 600 dp)
// ---------------------------------------------------------------------------

class _NavRail extends StatelessWidget {
  const _NavRail({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    required this.isDark,
    required this.showFab,
  });

  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool showFab;

  static const _selectedColor = AppColors.deepGreen;
  static const _unselectedColor = AppColors.gray;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final indicatorColor =
        isDark ? const Color(0xFF1E3A1E) : const Color(0xFFE8F5E9);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: NavigationRail(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          backgroundColor: Colors.transparent,
          indicatorColor: indicatorColor,
          selectedIconTheme:
              const IconThemeData(color: _selectedColor, size: 22),
          unselectedIconTheme:
              const IconThemeData(color: _unselectedColor, size: 22),
          selectedLabelTextStyle: const TextStyle(
            color: _selectedColor,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelTextStyle: const TextStyle(
            color: _unselectedColor,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: 11,
          ),
          labelType: NavigationRailLabelType.all,
          leading: showFab
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RailFab(),
                )
              : const SizedBox(height: 8),
          destinations: destinations
              .map(
                (d) => NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: d.badgeCount > 0,
                    label: Text(
                      d.badgeCount > 99 ? '99+' : '${d.badgeCount}',
                      style: const TextStyle(fontSize: 9),
                    ),
                    backgroundColor: Colors.red.shade600,
                    child: Icon(d.icon),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: d.badgeCount > 0,
                    label: Text(
                      d.badgeCount > 99 ? '99+' : '${d.badgeCount}',
                      style: const TextStyle(fontSize: 9),
                    ),
                    backgroundColor: Colors.red.shade600,
                    child: Icon(d.activeIcon),
                  ),
                  label: Text(d.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer FAB (rail variant — compact, no animation needed)
// ---------------------------------------------------------------------------

class _RailFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: () => context.push('/marketplace/add'),
      elevation: 2,
      backgroundColor: AppColors.warmOrange,
      foregroundColor: Colors.white,
      tooltip: 'Add Listing',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.add_rounded, size: 22),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;
}

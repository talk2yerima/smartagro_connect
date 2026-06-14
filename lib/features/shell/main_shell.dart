import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/auth_providers.dart';
import '../../domain/entities/app_user.dart';

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
    with SingleTickerProviderStateMixin {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destinations = _buildDestinations(role, isDark);
    final showFab = role == UserRole.farmer;

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
          label: 'Routes',
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
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

  static const _selectedColor = Color(0xFF1B5E20); // deepGreen
  static const _unselectedColor = Color(0xFF6B7280); // gray
  static const _indicatorColor = Color(0xFFE8F5E9); // very light green pill
  static const _indicatorColorDark = Color(0xFF1E3A1E);

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0);

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
          height: 64,
          child: Row(
            children: List.generate(destinations.length, (i) {
              return Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  isSelected: i == currentIndex,
                  selectedColor: _selectedColor,
                  unselectedColor: _unselectedColor,
                  indicatorColor: isDark ? _indicatorColorDark : _indicatorColor,
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
            child: Icon(
              isSelected ? destination.activeIcon : destination.icon,
              size: 22,
              color: color,
            )
                .animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(0.88, 0.88),
                  end: const Offset(1.0, 1.0),
                  duration: 220.ms,
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
      backgroundColor: const Color(0xFFFB8C00), // warmOrange
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
// Data model
// ---------------------------------------------------------------------------

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/auth_providers.dart';
import '../../domain/entities/app_user.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Profile Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8FAF5),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () {}, // decorative
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2E7D32),
        onRefresh: () async {
          // re-hydrate session if needed
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── [1] Hero Section ──────────────────────────────────────────
              _HeroSection(user: user, isDark: isDark),

              // ── [2] Stats Row ─────────────────────────────────────────────
              _StatsRow(user: user, isDark: isDark),

              const SizedBox(height: 8),

              // ── [3] Contact Card ──────────────────────────────────────────
              _ContactCard(user: user, isDark: isDark),

              const SizedBox(height: 8),

              // ── [4] Verification Card ─────────────────────────────────────
              _VerificationCard(isDark: isDark),

              const SizedBox(height: 8),

              // ── [5] Recent Activity ───────────────────────────────────────
              _RecentActivity(isDark: isDark),

              const SizedBox(height: 8),

              // ── [6] Danger Zone ───────────────────────────────────────────
              _DangerZone(ref: ref, context: context, isDark: isDark),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// [1] Hero Section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return Icons.grass_rounded;
      case UserRole.buyer:
        return Icons.shopping_basket_rounded;
      case UserRole.transporter:
        return Icons.local_shipping_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  String _roleName(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return 'Farmer';
      case UserRole.buyer:
        return 'Buyer';
      case UserRole.transporter:
        return 'Transporter';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Guest User';
    final role = user?.role ?? UserRole.farmer;
    final rating = user?.rating ?? 0.0;
    final verified = user?.verified ?? false;
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          // Avatar with camera overlay
          Stack(
            children: [
              AppAvatar(
                name: name,
                color: Colors.white.withValues(alpha: 0.30),
                radius: 48,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9A825),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // Role badge — custom pill with white text on translucent bg
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_roleIcon(role),
                    size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  _roleName(role),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          if (verified) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded,
                    size: 16, color: Color(0xFF00C853)),
                SizedBox(width: 4),
                Text(
                  'Verified Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Star rating row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  i <= fullStars
                      ? Icons.star_rounded
                      : (i == fullStars + 1 && hasHalf)
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  size: 20,
                  color: const Color(0xFFF9A825),
                ),
              const SizedBox(width: 6),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

// ---------------------------------------------------------------------------
// [2] Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF2E3C2E)),
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

  @override
  Widget build(BuildContext context) {
    final rating = user?.rating ?? 0.0;
    final stats = [
      const _StatItem(value: '12', label: 'Listings'),
      const _StatItem(value: '47', label: 'Trades'),
      _StatItem(value: rating.toStringAsFixed(1), label: 'Rating'),
      const _StatItem(value: '2023', label: 'Member Since'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: _card,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: stats
            .asMap()
            .entries
            .map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final isLast = idx == stats.length - 1;
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            right: BorderSide(
                              color: isDark
                                  ? const Color(0xFF2E3C2E)
                                  : const Color(0xFFE2EAE0),
                            ),
                          ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.value,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(),
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.04);
  }
}

class _StatItem {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;
}

// ---------------------------------------------------------------------------
// [3] Contact Card
// ---------------------------------------------------------------------------

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  BoxDecoration get _card => isDark
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

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? const Color(0xFFF8FAF5) : const Color(0xFF1F2937);
    final subColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final iconColor = const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Contact Information'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.email_outlined,
                      size: 18, color: iconColor),
                ),
                title: Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
                subtitle: Text(
                  user?.email ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: isDark
                    ? const Color(0xFF2E3C2E)
                    : const Color(0xFFE2EAE0),
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.phone_outlined,
                      size: 18, color: iconColor),
                ),
                title: Text(
                  'Phone',
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
                subtitle: Text(
                  user?.phone ?? 'Not provided',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// [4] Verification Card
// ---------------------------------------------------------------------------

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.isDark});

  final bool isDark;

  BoxDecoration get _card => isDark
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

  @override
  Widget build(BuildContext context) {
    final items = [
      const _VerifItem(
        label: 'Identity Verification',
        subtitle: 'Government ID confirmed',
        verified: true,
      ),
      const _VerifItem(
        label: 'Business Registration',
        subtitle: 'CAC certificate on file',
        verified: true,
      ),
      const _VerifItem(
        label: 'Bank Account',
        subtitle: 'Pending review',
        verified: false,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Verification Status'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.verified
                            ? const Color(0xFF00C853).withValues(alpha: 0.12)
                            : const Color(0xFFF9A825).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.verified
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_top_rounded,
                        size: 18,
                        color: item.verified
                            ? const Color(0xFF00C853)
                            : const Color(0xFFF9A825),
                      ),
                    ),
                    title: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFFF8FAF5)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    trailing: StatusBadge(
                      label: item.verified ? 'Verified' : 'Pending',
                      color: item.verified
                          ? const Color(0xFF00C853)
                          : const Color(0xFFF9A825),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark
                          ? const Color(0xFF2E3C2E)
                          : const Color(0xFFE2EAE0),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.04);
  }
}

class _VerifItem {
  const _VerifItem({
    required this.label,
    required this.subtitle,
    required this.verified,
  });
  final String label;
  final String subtitle;
  final bool verified;
}

// ---------------------------------------------------------------------------
// [5] Recent Activity
// ---------------------------------------------------------------------------

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.isDark});

  final bool isDark;

  BoxDecoration get _card => isDark
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

  static const _activities = [
    _ActivityItem(
      icon: Icons.add_box_rounded,
      title: 'Listed 50 bags of White Maize',
      date: 'Jun 10, 2026',
      color: Color(0xFF2E7D32),
    ),
    _ActivityItem(
      icon: Icons.handshake_rounded,
      title: 'Completed trade with Emeka Buyers Ltd',
      date: 'Jun 7, 2026',
      color: Color(0xFF0277BD),
    ),
    _ActivityItem(
      icon: Icons.star_rounded,
      title: 'Received 5-star rating from Fatima A.',
      date: 'Jun 5, 2026',
      color: Color(0xFFF9A825),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recent Activity'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: Column(
            children: _activities.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isLast = idx == _activities.length - 1;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon,
                          size: 18, color: item.color),
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFF8FAF5)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    subtitle: Text(
                      item.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark
                          ? const Color(0xFF2E3C2E)
                          : const Color(0xFFE2EAE0),
                    ),
                ],
              )
                  .animate(delay: (250 + idx * 50).ms)
                  .fadeIn()
                  .slideY(begin: 0.04);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

@immutable
class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.date,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String date;
  final Color color;
}

// ---------------------------------------------------------------------------
// [6] Danger Zone
// ---------------------------------------------------------------------------

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.ref,
    required this.context,
    required this.isDark,
  });

  final WidgetRef ref;
  final BuildContext context;
  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFC62828).withValues(alpha: 0.30)),
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
          border: Border.all(
              color: const Color(0xFFC62828).withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          ),
        ),
        content:
            const Text('Are you sure you want to sign out of SmartAgro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authSessionProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Account'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFFC62828),
              ),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFFC62828),
              ),
            ),
            subtitle: Text(
              'You will be returned to the login screen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC62828),
            ),
            onTap: _handleSignOut,
          ),
        ),
      ],
    ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.04);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/di/repositories_provider.dart';
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
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
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
            onPressed: () => context.push('/profile/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: () async {
          await Future.wait([
            ref.refresh(myListingsProvider.future),
            ref.refresh(userCreatedAtProvider.future),
            ref.refresh(notificationsProvider.future),
          ]);
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
              _VerificationCard(user: user, isDark: isDark),

              const SizedBox(height: 8),

              // ── [4.5] My Listings shortcut (farmers only) ─────────────────
              if (user?.role == UserRole.farmer) ...[
                _MyListingsCard(isDark: isDark),
                const SizedBox(height: 8),
                // Where sales money goes (Paystack split to their bank).
                _QuickLinkTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Get paid',
                  subtitle:
                      ref.watch(myPayoutAccountProvider).valueOrNull == null
                          ? 'Add your bank account to receive payments'
                          : 'Payments go to your bank account',
                  isDark: isDark,
                  onTap: () => context.push('/payouts'),
                ),
                const SizedBox(height: 8),
              ],

              // ── [4.6] Payment History shortcut ────────────────────────────
              _QuickLinkTile(
                icon: Icons.receipt_long_outlined,
                label: 'Orders',
                subtitle: 'Sales and purchases, with buyer and seller contacts',
                isDark: isDark,
                onTap: () => context.push('/orders'),
              ),

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
          colors: [AppColors.deepGreen, AppColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          // Avatar with camera overlay — taps to edit profile
          GestureDetector(
            onTap: () => context.push('/profile/edit'),
            child: Stack(
              children: [
                AppAvatar(
                  name: name,
                  color: Colors.white.withValues(alpha: 0.30),
                  radius: 48,
                  imageUrl: user?.avatarUrl,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.golden,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_roleIcon(role), size: 13, color: Colors.white),
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
                    size: 16, color: AppColors.mintGreen),
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
                  color: AppColors.golden,
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

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
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
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = user?.rating ?? 0.0;

    final listingCount = ref.watch(myListingsProvider).maybeWhen(
          data: (list) => '${list.length}',
          orElse: () => '—',
        );
    final sinceYear = ref.watch(userCreatedAtProvider).maybeWhen(
          data: (dt) => dt != null ? '${dt.year}' : '—',
          orElse: () => '—',
        );

    final stats = [
      _StatItem(value: listingCount, label: 'Listings'),
      _StatItem(value: rating.toStringAsFixed(1), label: 'Rating'),
      _StatItem(value: user?.verified == true ? '✓' : '—', label: 'Verified'),
      _StatItem(value: sinceYear, label: 'Since'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: _card,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: stats.asMap().entries.map((entry) {
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
                              ? AppColors.darkBorder
                              : AppColors.borderLight,
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
                      color: AppColors.deepGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.silver : AppColors.gray,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
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
          border: Border.all(color: AppColors.borderLight),
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
    final textColor = isDark ? AppColors.softWhite : AppColors.charcoal;
    final subColor = isDark ? AppColors.silver : AppColors.gray;
    final iconColor = AppColors.emerald;

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
                    color: AppColors.deepGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.email_outlined, size: 18, color: iconColor),
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
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.deepGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.phone_outlined, size: 18, color: iconColor),
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
              if (user?.location != null && (user!.location!.isNotEmpty)) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                ),
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.deepGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.location_on_outlined,
                        size: 18, color: iconColor),
                  ),
                  title: Text(
                    'Location',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                  subtitle: Text(
                    user!.location!,
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
  const _VerificationCard({required this.user, required this.isDark});

  final AppUser? user;
  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
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
          border: Border.all(color: AppColors.borderLight),
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
    final accountVerified = user?.verified ?? false;
    final phoneLinked = (user?.phone ?? '').isNotEmpty;

    final items = [
      _VerifItem(
        label: 'Account Verified',
        subtitle: accountVerified ? 'Identity confirmed' : 'Pending review',
        verified: accountVerified,
      ),
      // The number is only typed in, never checked by SMS yet, so say
      // "Added", not "Verified".
      _VerifItem(
        label: 'Phone Number',
        subtitle: phoneLinked ? user!.phone! : 'Not provided',
        verified: phoneLinked,
        doneLabel: 'Added',
        pendingLabel: 'Not added',
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
                            ? AppColors.mintGreen.withValues(alpha: 0.12)
                            : AppColors.golden.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.verified
                            ? Icons.check_circle_rounded
                            : Icons.hourglass_top_rounded,
                        size: 18,
                        color: item.verified
                            ? AppColors.mintGreen
                            : AppColors.golden,
                      ),
                    ),
                    title: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color:
                            isDark ? AppColors.softWhite : AppColors.charcoal,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.silver : AppColors.gray,
                      ),
                    ),
                    trailing: StatusBadge(
                      label: item.verified ? item.doneLabel : item.pendingLabel,
                      color: item.verified
                          ? AppColors.mintGreen
                          : AppColors.golden,
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color:
                          isDark ? AppColors.darkBorder : AppColors.borderLight,
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
    this.doneLabel = 'Verified',
    this.pendingLabel = 'Pending',
  });
  final String label;
  final String subtitle;
  final bool verified;

  /// Badge text when [verified] is true / false.
  final String doneLabel;
  final String pendingLabel;
}

// ---------------------------------------------------------------------------
// [4.5] My Listings shortcut
// ---------------------------------------------------------------------------

class _MyListingsCard extends StatelessWidget {
  const _MyListingsCard({required this.isDark});

  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
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
          border: Border.all(color: AppColors.borderLight),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'My Listings'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.deepGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppColors.emerald,
              ),
            ),
            title: Text(
              'Manage your product listings',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? AppColors.softWhite : AppColors.charcoal,
              ),
            ),
            subtitle: Text(
              'Edit, delete or add new listings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.silver : AppColors.gray,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.emerald,
            ),
            onTap: () => context.push('/my-listings'),
          ),
        ),
      ],
    ).animate(delay: 225.ms).fadeIn().slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// Quick-link tile (generic shortcut card used in the profile body)
// ---------------------------------------------------------------------------

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        )
      : BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _card,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.deepGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.deepGreen),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.softWhite : AppColors.charcoal,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.silver : AppColors.gray,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.deepGreen),
        onTap: onTap,
      ),
    ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.04);
  }
}

// ---------------------------------------------------------------------------
// [5] Recent Activity
// ---------------------------------------------------------------------------

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.isDark});

  final bool isDark;

  BoxDecoration get _card => isDark
      ? BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
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
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

  IconData _iconFor(String type) {
    switch (type) {
      case 'price_alert':
        return Icons.show_chart_rounded;
      case 'new_buyer':
        return Icons.person_add_outlined;
      case 'order':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'price_alert':
        return AppColors.golden;
      case 'new_buyer':
        return AppColors.infoBlue;
      case 'order':
        return AppColors.emerald;
      default:
        return AppColors.gray;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    Widget body = const SizedBox.shrink();
    notificationsAsync.when(
      loading: () => body = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _card,
        height: 80,
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.emerald),
        ),
      ),
      error: (_, __) => body = const SizedBox.shrink(),
      data: (notifications) {
        if (notifications.isEmpty) {
          body = Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _card,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No recent activity yet',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.silver : AppColors.gray,
                ),
              ),
            ),
          );
          return;
        }
        final items = notifications.take(5).toList();
        body = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final n = entry.value;
              final isLast = idx == items.length - 1;
              final color = _colorFor(n.type);
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconFor(n.type), size: 18, color: color),
                    ),
                    title: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color:
                            isDark ? AppColors.softWhite : AppColors.charcoal,
                      ),
                    ),
                    subtitle: Text(
                      n.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.silver : AppColors.gray,
                      ),
                    ),
                    trailing: Text(
                      _timeAgo(n.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.silver : AppColors.gray,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color:
                          isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                ],
              )
                  .animate(delay: (250 + idx * 50).ms)
                  .fadeIn()
                  .slideY(begin: 0.04);
            }).toList(),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recent Activity'),
        body,
      ],
    );
  }
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
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.30)),
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
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.25)),
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
        content: const Text('Are you sure you want to sign out of SmartAgro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorRed,
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
                color: AppColors.errorRed.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.errorRed,
              ),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.errorRed,
              ),
            ),
            subtitle: Text(
              'You will be returned to the login screen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.silver : AppColors.gray,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.errorRed,
            ),
            onTap: _handleSignOut,
          ),
        ),
      ],
    ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.04);
  }
}

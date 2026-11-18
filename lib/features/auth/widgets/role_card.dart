import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/app_user.dart';

/// A large tappable choice of role (Farmer / Buyer / Transporter), used
/// at sign-up and when a new phone user sets up their profile.
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon) = switch (role) {
      UserRole.farmer => (
          'Farmer',
          'Sell my produce',
          Icons.agriculture_outlined,
        ),
      UserRole.buyer => (
          'Buyer',
          'Buy produce from farmers',
          Icons.storefront_outlined,
        ),
      UserRole.transporter => (
          'Transporter',
          'Deliver produce',
          Icons.local_shipping_outlined,
        ),
      UserRole.admin => (
          'Admin',
          'Manage the marketplace',
          Icons.admin_panel_settings_outlined,
        ),
    };
    final accent = isDark ? AppColors.lightGreen : AppColors.deepGreen;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
            : AppColors.card(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? accent : AppColors.border_(isDark),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.subText(isDark)),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? accent : AppColors.subText(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

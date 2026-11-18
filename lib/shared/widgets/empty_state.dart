import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Context hint — drives the illustration palette and secondary icon.
enum EmptyStateType {
  marketplace,
  market,
  buyers,
  chat,
  search,
  generic,
}

/// Visually-rich empty-state with a layered illustration area, title,
/// subtitle, and an optional action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.type = EmptyStateType.generic,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EmptyStateType type;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final palette = _palette(type);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Illustration area ──────────────────────────────────────────
            SizedBox(
              width: 200,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background blob
                  Positioned(
                    top: 0,
                    left: 10,
                    child: _Bubble(
                      size: 110,
                      color: palette.primary
                          .withValues(alpha: isDark ? 0.08 : 0.10),
                    ),
                  ),
                  // Secondary blob
                  Positioned(
                    bottom: 0,
                    right: 10,
                    child: _Bubble(
                      size: 80,
                      color: palette.accent
                          .withValues(alpha: isDark ? 0.07 : 0.09),
                    ),
                  ),
                  // Small dot — top right
                  Positioned(
                    top: 14,
                    right: 28,
                    child: _Bubble(
                      size: 18,
                      color: palette.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  // Small dot — bottom left
                  Positioned(
                    bottom: 16,
                    left: 24,
                    child: _Bubble(
                      size: 12,
                      color: palette.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  // Main icon circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.primary
                              .withValues(alpha: isDark ? 0.25 : 0.14),
                          palette.accent
                              .withValues(alpha: isDark ? 0.18 : 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.primary
                            .withValues(alpha: isDark ? 0.30 : 0.18),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 44,
                      color: palette.primary
                          .withValues(alpha: isDark ? 0.85 : 0.70),
                    ),
                  ),
                  // Secondary hint icon
                  Positioned(
                    bottom: 18,
                    right: 30,
                    child: ExcludeSemantics(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: palette.accent
                              .withValues(alpha: isDark ? 0.20 : 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          palette.secondaryIcon,
                          size: 15,
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Title ──────────────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
              ),
            ),

            const SizedBox(height: 8),

            // ── Subtitle ───────────────────────────────────────────────────
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.gray,
                height: 1.55,
              ),
            ),

            // ── Optional action button ─────────────────────────────────────
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                icon: Icon(palette.ctaIcon, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _EmptyPalette _palette(EmptyStateType t) {
    return switch (t) {
      EmptyStateType.marketplace => const _EmptyPalette(
          primary: AppColors.emerald,
          accent: AppColors.golden,
          secondaryIcon: Icons.add_shopping_cart_rounded,
          ctaIcon: Icons.add_box_outlined,
        ),
      EmptyStateType.market => const _EmptyPalette(
          primary: AppColors.deepGreen,
          accent: AppColors.mintGreen,
          secondaryIcon: Icons.show_chart_rounded,
          ctaIcon: Icons.refresh_rounded,
        ),
      EmptyStateType.buyers => const _EmptyPalette(
          primary: AppColors.infoBlue,
          accent: AppColors.freshGreen,
          secondaryIcon: Icons.location_on_rounded,
          ctaIcon: Icons.map_outlined,
        ),
      EmptyStateType.chat => const _EmptyPalette(
          primary: AppColors.emerald,
          accent: AppColors.lightGreen,
          secondaryIcon: Icons.send_rounded,
          ctaIcon: Icons.chat_bubble_outline_rounded,
        ),
      EmptyStateType.search => const _EmptyPalette(
          primary: AppColors.gray,
          accent: AppColors.emerald,
          secondaryIcon: Icons.tune_rounded,
          ctaIcon: Icons.refresh_rounded,
        ),
      EmptyStateType.generic => const _EmptyPalette(
          primary: AppColors.emerald,
          accent: AppColors.lightGreen,
          secondaryIcon: Icons.info_outline_rounded,
          ctaIcon: Icons.refresh_rounded,
        ),
    };
  }
}

// ─── Internal helpers ─────────────────────────────────────────────────────────

class _EmptyPalette {
  const _EmptyPalette({
    required this.primary,
    required this.accent,
    required this.secondaryIcon,
    required this.ctaIcon,
  });

  final Color primary;
  final Color accent;
  final IconData secondaryIcon;
  final IconData ctaIcon;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

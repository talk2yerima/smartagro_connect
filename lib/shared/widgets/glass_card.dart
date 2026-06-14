import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft glass surface for premium cards.
///
/// Light mode: white background at 0.92 opacity with a subtle border and
/// optional backdrop blur.
/// Dark mode: dark card background at 0.88 opacity with a darker border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.tintColor,
    this.borderRadius,
  });

  final Widget child;

  /// Inner padding. Defaults to [EdgeInsets.all(16)].
  final EdgeInsetsGeometry? padding;

  /// Optional tint overlaid on top of the background colour. When provided it
  /// replaces the default white / dark-card colour entirely, so callers can
  /// apply any brand tint while keeping the glass treatment.
  final Color? tintColor;

  /// Corner radius. Defaults to 16.
  final double? borderRadius;

  // ─── helpers ───────────────────────────────────────────────────────────────

  static const double _defaultRadius = 16;
  static const EdgeInsetsGeometry _defaultPadding = EdgeInsets.all(16);

  // Light-mode colours
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE2EAE0);

  // Dark-mode colours
  static const Color _darkBg = Color(0xFF1E1E1E);
  static const Color _darkBorder = Color(0xFF2E3C2E);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? _defaultRadius;
    final effectivePadding = padding ?? _defaultPadding;

    final bgColor = tintColor != null
        ? tintColor!.withValues(alpha: isDark ? 0.88 : 0.92)
        : isDark
            ? _darkBg.withValues(alpha: 0.88)
            : _lightBg.withValues(alpha: 0.92);

    final borderColor = isDark
        ? _darkBorder
        : (tintColor != null
            ? tintColor!.withValues(alpha: 0.18)
            : _lightBorder);

    final decoration = BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    // Apply a light backdrop blur only — keeps the Material feel clean without
    // an overwhelming frosted-glass look.
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: effectivePadding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}

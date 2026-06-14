import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

// ─── Shared helpers ──────────────────────────────────────────────────────────

const _kHeight = 52.0;
const _kRadius = 12.0;
const _kDisabledOpacity = 0.6;

const _kGreenGradient = LinearGradient(
  colors: [AppColors.deepGreen, AppColors.emerald],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _kAmberGradient = LinearGradient(
  colors: [AppColors.golden, AppColors.warmOrange],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

TextStyle _buttonTextStyle() => GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );

// ─── PrimaryGradientButton ────────────────────────────────────────────────────

/// Full-width, 52 px, deepGreen → emerald gradient CTA.
/// Shows a [CircularProgressIndicator] when [label] ends with '…' or '...'.
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  bool get _isLoading => label.endsWith('...') || label.endsWith('…');

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final btn = Opacity(
      opacity: isDisabled ? _kDisabledOpacity : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _kGreenGradient,
          borderRadius: BorderRadius.circular(_kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_kRadius),
            onTap: isDisabled || _isLoading ? null : onPressed,
            child: SizedBox(
              height: _kHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ] else ...[
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: _buttonTextStyle()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.97, 0.97),
          duration: 100.ms,
        )
        .then()
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 100.ms,
        );

    if (expanded) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

// ─── SecondaryGradientButton ──────────────────────────────────────────────────

/// Full-width, 52 px, golden → warmOrange gradient button.
class SecondaryGradientButton extends StatelessWidget {
  const SecondaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  bool get _isLoading => label.endsWith('...') || label.endsWith('…');

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final btn = Opacity(
      opacity: isDisabled ? _kDisabledOpacity : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _kAmberGradient,
          borderRadius: BorderRadius.circular(_kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_kRadius),
            onTap: isDisabled || _isLoading ? null : onPressed,
            child: SizedBox(
              height: _kHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ] else ...[
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: _buttonTextStyle()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.97, 0.97),
          duration: 100.ms,
        )
        .then()
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 100.ms,
        );

    if (expanded) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

// ─── GhostButton ─────────────────────────────────────────────────────────────

/// Full-width, 52 px, transparent with deepGreen border and deepGreen text.
/// Adapts border/text color to dark mode using freshGreen.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  bool get _isLoading => label.endsWith('...') || label.endsWith('…');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.freshGreen : AppColors.deepGreen;
    final textColor =
        isDark ? AppColors.freshGreen : AppColors.deepGreen;
    final isDisabled = onPressed == null;

    final textStyle = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: textColor,
    );

    final btn = Opacity(
      opacity: isDisabled ? _kDisabledOpacity : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(_kRadius),
            onTap: isDisabled || _isLoading ? null : onPressed,
            child: SizedBox(
              height: _kHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                  ] else ...[
                    if (icon != null) ...[
                      Icon(icon, color: textColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: textStyle),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.97, 0.97),
          duration: 100.ms,
        )
        .then()
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 100.ms,
        );

    if (expanded) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Adaptive metric card — switches to compact horizontal layout on small grids.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.unit,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
  final String? unit;

  static BoxDecoration _card(bool isDark) => BoxDecoration(
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

  Widget _trendChip() {
    final up = trend! >= 0;
    final chipColor = up ? const Color(0xFF00C853) : const Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 10,
            color: chipColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${up ? '+' : ''}${trend!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final grayColor = const Color(0xFF6B7280);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact mode: height too small for vertical layout
        final compact = constraints.maxHeight < 88;
        final pad = compact ? 10.0 : 14.0;
        final iconSize = compact ? 28.0 : 36.0;

        if (compact) {
          return Container(
            decoration: _card(isDark),
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: iconSize * 0.55),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              style: textTheme.titleMedium?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unit != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              unit!,
                              style: textTheme.bodySmall?.copyWith(
                                  color: grayColor, fontSize: 10),
                              maxLines: 1,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        label,
                        style: textTheme.bodySmall?.copyWith(
                            color: grayColor, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(width: 4),
                  _trendChip(),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms);
        }

        // Full vertical layout
        return Container(
          decoration: _card(isDark),
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: iconSize * 0.55),
                  ),
                  if (trend != null) _trendChip(),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: textTheme.headlineSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        unit!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: grayColor, fontWeight: FontWeight.w500),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(color: grayColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms);
      },
    );
  }
}

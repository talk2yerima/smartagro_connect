import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A single rounded shimmer block — use for inline placeholders.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton placeholder list for slow networks / cold starts.
///
/// Parameters:
///   [count]      — number of skeleton items to render (required)
///   [height]     — total height of each skeleton row (default 72)
///   [showAvatar] — when true, renders a circle avatar placeholder on the left
///                  with two text-line stubs on the right; when false, renders
///                  two text-line stubs spanning the full width.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.count,
    this.height = 72,
    this.showAvatar = false,
  });

  final int count;
  final double height;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, _) => _SkeletonItem(
          height: height,
          showAvatar: showAvatar,
        ),
      ),
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem({
    required this.height,
    required this.showAvatar,
  });

  final double height;
  final bool showAvatar;

  Widget _block({
    required double width,
    required double blockHeight,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: blockHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showAvatar) {
      return SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circle avatar placeholder
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Two text-line stubs
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(width: double.infinity, blockHeight: 14),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) => _block(
                      width: constraints.maxWidth * 0.55,
                      blockHeight: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No avatar — two lines spanning full width
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => _block(
              width: constraints.maxWidth * 0.70,
              blockHeight: 14,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => _block(
              width: constraints.maxWidth * 0.40,
              blockHeight: 12,
            ),
          ),
        ],
      ),
    );
  }
}

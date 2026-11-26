import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/constants/app_colors.dart';
import '../../core/i18n/i18n.dart';
import 'skeleton_list.dart';

/// True when [url] is a real uploaded photo. Empty URLs and the random
/// stock pictures (picsum.photos) that older listings were given in place
/// of a photo count as "no photo".
bool hasRealPhoto(String url) =>
    url.trim().isNotEmpty && !url.contains('picsum.photos');

/// A listing photo: disk-cached, decoded at the size it is shown (saves
/// memory and data on low-end phones), a theme-aware shimmer while it loads,
/// and a calm produce placeholder when there is no photo or it fails.
class ProduceImage extends StatelessWidget {
  const ProduceImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 36,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!hasRealPhoto(url)) return _placeholder(isDark);

    // Decode at the on-screen pixel size; full-width when width is unknown.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth = width ?? MediaQuery.sizeOf(context).width;
    final cacheWidth = (logicalWidth * dpr).round().clamp(64, 1440);

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: skeletonBase(isDark),
        highlightColor: skeletonHighlight(isDark),
        child: Container(width: width, height: height, color: Colors.white),
      ),
      errorWidget: (_, __, ___) => _placeholder(isDark),
    );
  }

  Widget _placeholder(bool isDark) {
    return Semantics(
      label: tr('No photo'),
      child: Container(
        width: width,
        height: height,
        color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
        alignment: Alignment.center,
        child: Icon(
          Icons.eco_outlined,
          size: iconSize,
          color: (isDark ? AppColors.lightGreen : AppColors.emerald)
              .withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

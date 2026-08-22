import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Pulsing skeleton cards that match the shape of incoming menu items.
///
/// Replaces spinning loading circles with soft-grey skeleton tiles that
/// perfectly mirror the layout of `_MenuItemTile` — image placeholder
/// on the right, title/description/price lines on the left.
class MenuShimmerGrid extends StatelessWidget {
  const MenuShimmerGrid({
    super.key,
    this.itemCount = 8,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final highlightColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => const _MenuItemSkeleton(),
      ),
    );
  }
}

/// A single skeleton menu item tile matching the `_MenuItemTile` layout.
class _MenuItemSkeleton extends StatelessWidget {
  const _MenuItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: title, description, price lines
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Veg/non-veg badge + title
              Row(
                children: [
                  _box(16, 16, radius: 3),
                  const SizedBox(width: 8),
                  _box(140, 16, radius: 4),
                ],
              ),
              const SizedBox(height: 8),
              // Description line 1
              _box(double.infinity, 12, radius: 4),
              const SizedBox(height: 6),
              // Description line 2 (shorter)
              _box(200, 12, radius: 4),
              const SizedBox(height: 12),
              // Price
              _box(60, 16, radius: 4),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right side: image placeholder (80x80)
        _box(80, 80, radius: 12),
      ],
    );
  }

  Widget _box(double width, double height, {double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton grid for venue cards on the discovery screen.
class VenueShimmerList extends StatelessWidget {
  const VenueShimmerList({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final highlightColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1200),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => const _VenueCardSkeleton(),
      ),
    );
  }
}

class _VenueCardSkeleton extends StatelessWidget {
  const _VenueCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image placeholder (full width, 180px)
        _box(double.infinity, 180, radius: 16),
        const SizedBox(height: 12),
        // Name line
        _box(200, 18, radius: 4),
        const SizedBox(height: 8),
        // Subtitle line
        _box(140, 14, radius: 4),
        const SizedBox(height: 8),
        // Rating + category row
        Row(
          children: [
            _box(50, 24, radius: 12),
            const SizedBox(width: 8),
            _box(80, 14, radius: 4),
          ],
        ),
      ],
    );
  }

  Widget _box(double width, double height, {double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

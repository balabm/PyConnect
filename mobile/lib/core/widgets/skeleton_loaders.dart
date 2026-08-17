import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

final Color _skeletonBase = Colors.grey.shade200;
final Color _skeletonHighlight = Colors.grey.shade100;

Widget _shimmer(Widget child) => Shimmer.fromColors(
      baseColor: _skeletonBase,
      highlightColor: _skeletonHighlight,
      child: child,
    );

Widget _line(double height, double width, {double radius = 4}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

/// 160x200 rounded venue/stay placeholder block with an image header,
/// title line and subtitle line. Default margin matches list cards.
class VenueCardSkeleton extends StatelessWidget {
  const VenueCardSkeleton({
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        margin: margin,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 180,
              color: _skeletonBase,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(16, 140),
                  const SizedBox(height: 8),
                  _line(12, 200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 80x80 image placeholder with title and price lines.
class MenuItemSkeleton extends StatelessWidget {
  const MenuItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(15, double.infinity),
                  const SizedBox(height: 8),
                  _line(12, 120),
                  const SizedBox(height: 8),
                  _line(12, 80),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _skeletonBase,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width card with icon and text lines.
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _skeletonBase,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(15, double.infinity),
                  const SizedBox(height: 4),
                  _line(12, 120),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(14, 70),
                const SizedBox(height: 4),
                _line(12, 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 120x120 square quick-essential product card.
class QuickEssentialSkeleton extends StatelessWidget {
  const QuickEssentialSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _skeletonBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(13, double.infinity),
                  const SizedBox(height: 8),
                  _line(15, 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large horizontal card for home vibes / experiences.
class HomeVibeSkeleton extends StatelessWidget {
  const HomeVibeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              height: 120,
              color: _skeletonBase,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(16, 140),
                  const SizedBox(height: 4),
                  _line(12, 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Booking detail placeholder with icon and amount.
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _skeletonBase.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _skeletonBase,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _line(15, double.infinity),
                  const SizedBox(height: 8),
                  _line(12, 120),
                  const SizedBox(height: 8),
                  _line(12, 80),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _line(14, 60),
          ],
        ),
      ),
    );
  }
}

/// Which skeleton shape to render in a [SkeletonList].
enum SkeletonType {
  venue,
  restaurant,
  menu,
  activity,
  quickEssential,
  stay,
  homeVibe,
  booking,
}

/// Consistent loading placeholder that renders a list or grid of the
/// requested skeleton type.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.type,
    this.count = 6,
  });

  final SkeletonType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case SkeletonType.quickEssential:
        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: count,
          itemBuilder: (_, index) => const QuickEssentialSkeleton(),
        );
      case SkeletonType.venue:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const VenueCardSkeleton(),
        );
      case SkeletonType.restaurant:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const VenueCardSkeleton(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        );
      case SkeletonType.menu:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const MenuItemSkeleton(),
        );
      case SkeletonType.activity:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const ActivityCardSkeleton(),
        );
      case SkeletonType.stay:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const VenueCardSkeleton(
            margin: EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          ),
        );
      case SkeletonType.homeVibe:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const HomeVibeSkeleton(),
        );
      case SkeletonType.booking:
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (_, index) => const BookingCardSkeleton(),
        );
    }
  }
}

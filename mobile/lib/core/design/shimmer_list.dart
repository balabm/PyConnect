import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Generic shimmer loading placeholder for list-based screens.
///
/// Renders [count] skeleton cards with configurable image header.
class ShimmerList extends StatefulWidget {
  const ShimmerList({
    super.key,
    this.count = 5,
    this.withImage = true,
    this.itemHeight = 92,
  });

  final int count;
  final bool withImage;
  final double itemHeight;

  @override
  State<ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppTheme.darkCard : Colors.grey.shade300;
    final highlightColor = isDark ? AppTheme.darkSurface : Colors.grey.shade100;
    final blockColor = isDark ? AppTheme.darkSurface : Colors.grey.shade400;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: widget.count,
      itemBuilder: (_, _) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            final value = (_controller.value * 2).clamp(0.0, 1.0);
            final opacity = _controller.value < 0.5
                ? 0.3 + 0.2 * value
                : 0.5 - 0.2 * (value - 1);
            return ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  colors: [
                    baseColor,
                    highlightColor,
                    baseColor,
                  ],
                  stops: [0.0, opacity, 1.0],
                ).createShader(rect);
              },
              child: child!,
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                if (widget.withImage) ...[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: 140,
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        height: 12,
                        width: 90,
                        decoration: BoxDecoration(
                          color: blockColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

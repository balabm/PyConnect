import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A dark-mode-aware shimmer loader wrapper.
///
/// Detects `Theme.of(context).brightness` and uses appropriate
/// skeleton colors:
/// - Light mode: `Colors.grey[200]` base, `Colors.grey[100]` highlight
/// - Dark mode: `Colors.grey[900]` base, `Colors.grey[800]` highlight
///
/// This ensures loading states feel cohesive with the OLED aesthetic
/// instead of the "muddy grey" look of default shimmer in dark mode.
class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1200),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = baseColor ??
        (isDark ? Colors.grey.shade900 : Colors.grey.shade200);
    final highlight = highlightColor ??
        (isDark ? Colors.grey.shade800 : Colors.grey.shade100);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: period,
      child: child,
    );
  }
}

/// A simple shimmer box with theme-aware colors.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade900 : Colors.grey.shade200;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

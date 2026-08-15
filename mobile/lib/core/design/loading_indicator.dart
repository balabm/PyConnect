import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Animated loading indicator with three pulsing dots.
/// Use for inline loading states (button loading, card loading, etc.)
class LoadingDots extends StatefulWidget {
  const LoadingDots({
    super.key,
    this.color = AppTheme.lagoon,
    this.size = 8,
    this.spacing = 4,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Color color;
  final double size;
  final double spacing;
  final Duration duration;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(
            left: i == 0 ? 0 : widget.spacing,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, _) {
              // Stagger the three dots
              final delay = i / 3;
              final t = (_controller.value - delay).clamp(0.0, 1.0 / 3) * 3;
              final scale = 0.5 + 0.5 * (0.5 - (t - 0.5).abs() * 2);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

/// Full-screen loading overlay with branded spinner.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message = 'Loading',
    this.backgroundOpacity = 0.4,
  });

  final String message;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: backgroundOpacity),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppTheme.lagoon,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated skeleton block for custom skeleton layouts.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 4,
    this.margin,
  });

  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final value = (_controller.value * 2).clamp(0.0, 1.0);
        final opacity = _controller.value < 0.5
            ? 0.3 + 0.2 * value
            : 0.5 - 0.2 * (value - 1);
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

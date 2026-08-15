import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted-glass card with backdrop blur for premium overlay UIs.
/// Use on top of images, maps, or gradients for a modern glassmorphism effect.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.85,
    this.borderRadius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.showBorder = true,
    this.onTap,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool showBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dark variant of [GlassCard] for use on light backgrounds.
class DarkGlassCard extends StatelessWidget {
  const DarkGlassCard({
    super.key,
    required this.child,
    this.blur = 12,
    this.opacity = 0.7,
    this.borderRadius = AppRadius.lg,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

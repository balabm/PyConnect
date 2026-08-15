import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// A versatile card with optional image header, gradient overlay, and badge slot.
///
/// Used for venue cards, restaurant cards, experience cards, etc.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.imageUrl,
    this.imageHeight = 120,
    this.gradient,
    this.badge,
    this.onTap,
    this.padding,
    this.margin,
  });

  final Widget child;
  final String? imageUrl;
  final double imageHeight;
  final LinearGradient? gradient;
  final Widget? badge;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : AppTheme.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null || gradient != null)
                Stack(
                  children: [
                    Container(
                      height: imageHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: gradient ?? AppTheme.sunsetGradient,
                      ),
                      child: imageUrl != null
                          ? AppNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              height: imageHeight,
                              fallbackIcon: Icons.image_outlined,
                            )
                          : null,
                    ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: badge!,
                      ),
                  ],
                ),
              Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

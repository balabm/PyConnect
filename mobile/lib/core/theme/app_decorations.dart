import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Centralized decoration tokens for the PY Connect design system.
///
/// Provides reusable [BoxDecoration] presets for glassmorphism surfaces,
/// modern cards, floating pills, and ambient shadows. All decorations
/// respect the current theme (light/dark) via [BuildContext].
class AppDecorations {
  AppDecorations._();

  // ── Glassmorphism ──

  /// Frosted glass surface with backdrop blur.
  /// Use inside a [ClipRRect] or [BackdropFilter] wrapper.
  static BoxDecoration glass(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        width: 0.5,
      ),
    );
  }

  /// Frosted glass surface with stronger opacity for floating elements.
  static BoxDecoration glassStrong(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? AppTheme.darkSurface : Colors.white).withOpacity(0.85),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── Modern Cards ──

  /// Modern card with soft ambient shadow and subtle border.
  static BoxDecoration modernCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppTheme.darkCard : AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(
          isDark ? 0.06 : 0.04,
        ),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.20 : 0.04),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  /// Modern card with a colored accent glow (for highlighted items).
  static BoxDecoration modernCardWithGlow(
    BuildContext context,
    Color glowColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppTheme.darkCard : AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: glowColor.withOpacity(0.15),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.20 : 0.04),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ── Floating Pills ──

  /// Floating pill decoration for cart summary, nav bar, etc.
  static BoxDecoration floatingPill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? AppTheme.darkSurface : Colors.white).withOpacity(0.90),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.30 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── Status Badges ──

  /// Pill-shaped status badge with a subtle glow.
  static BoxDecoration statusBadge(BuildContext context, Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withOpacity(0.25), width: 0.5),
    );
  }

  /// Glowing status badge with ambient shadow.
  static BoxDecoration glowingBadge(BuildContext context, Color color) {
    return BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: color.withOpacity(0.30), width: 0.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.20),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // ── Shadows ──

  /// Soft ambient shadow for floating elements.
  static List<BoxShadow> ambientShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.30 : 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// Colored glow shadow for highlighted elements.
  static List<BoxShadow> coloredGlow(Color color, {double opacity = 0.15}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ];
  }
}

/// A frosted glass container widget that applies [BackdropFilter] blur
/// and the [AppDecorations.glassStrong] decoration.
///
/// Use for floating headers, bottom sheets, and HUD overlays.
class AppGlassContainer extends StatelessWidget {
  const AppGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.blurSigmaX = 10,
    this.blurSigmaY = 10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;
  final double blurSigmaX;
  final double blurSigmaY;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.xl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigmaX,
          sigmaY: blurSigmaY,
        ),
        child: Container(
          decoration: AppDecorations.glassStrong(context).copyWith(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// A modern card with soft ambient shadow and subtle border.
/// Replaces flat [Card] widgets with depth and tactile feel.
class AppModernCard extends StatelessWidget {
  const AppModernCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glowColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? glowColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final decoration = glowColor != null
        ? AppDecorations.modernCardWithGlow(context, glowColor!)
        : AppDecorations.modernCard(context);

    final radius = borderRadius ?? AppRadius.lg;

    return Container(
      decoration: decoration.copyWith(
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

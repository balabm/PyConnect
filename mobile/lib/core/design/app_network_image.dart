import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A reusable network image widget with shimmer placeholder, error fallback,
/// and theme-aware colors. Replaces raw `Image.network` throughout the app.
///
/// Uses [CachedNetworkImage] for caching so images don't re-download on
/// every widget rebuild.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackColor,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? height;
  final double? width;
  final double? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final shimmerBase = Theme.of(context).colorScheme.surfaceContainerHighest;
    final shimmerHighlight = Theme.of(context).colorScheme.surface;

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      height: height,
      width: width,
      placeholder: (context, url) => _ShimmerPlaceholder(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        height: height,
        width: width,
      ),
      errorWidget: (context, url, error) => Container(
        height: height,
        width: width,
        color: fallbackColor ?? placeholderColor,
        child: Icon(
          fallbackIcon,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: image,
      );
    }
    return image;
  }
}

/// Animated shimmer placeholder shown while the network image loads.
class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder({
    required this.baseColor,
    required this.highlightColor,
    this.height,
    this.width,
  });

  final Color baseColor;
  final Color highlightColor;
  final double? height;
  final double? width;

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
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
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(dx, 0),
              end: Alignment(dx + 1, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
            ).createShader(rect);
          },
          child: child!,
        );
      },
      child: Container(
        height: widget.height,
        width: widget.width,
        color: widget.baseColor,
      ),
    );
  }
}

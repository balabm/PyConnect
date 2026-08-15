import 'package:flutter/material.dart';

/// Reusable staggered entrance animations for lists and grids.
/// These use Flutter's built-in animation framework (no external deps)
/// and are test-safe (no pending timers after disposal).

/// A widget that animates its child in with a fade + slide up effect.
/// Use for individual card entrances.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = const Offset(0, 0.15),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// A widget that animates its child in with a scale + fade effect.
/// Use for hero cards, feature highlights, and modal content.
class ScaleFadeIn extends StatefulWidget {
  const ScaleFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.beginScale = 0.92,
    this.curve = Curves.easeOutBack,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  @override
  State<ScaleFadeIn> createState() => _ScaleFadeInState();
}

class _ScaleFadeInState extends State<ScaleFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Wraps a list of children with staggered fade-slide entrances.
/// Each child animates in with an incremental delay.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 80),
    this.duration = const Duration(milliseconds: 400),
    this.direction = Axis.vertical,
  });

  final List<Widget> children;
  final Duration itemDelay;
  final Duration duration;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < children.length; i++)
          FadeSlideIn(
            delay: itemDelay * i,
            duration: duration,
            offset: direction == Axis.vertical
                ? const Offset(0, 0.15)
                : const Offset(0.15, 0),
            child: children[i],
          ),
      ],
    );
  }
}

/// Animated pulse for live indicators (e.g. "online" dots, recording dots).
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.color = const Color(0xFF0D9488),
    this.size = 8,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Color color;
  final double size;
  final Duration duration;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
        final scale = 1.0 + 0.3 * _controller.value;
        final opacity = 1.0 - 0.5 * _controller.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// Shimmering glow overlay for "live" or "new" badges.
class ShimmerGlow extends StatefulWidget {
  const ShimmerGlow({
    super.key,
    required this.child,
    this.color = const Color(0xFF0D9488),
    this.duration = const Duration(milliseconds: 2000),
  });

  final Widget child;
  final Color color;
  final Duration duration;

  @override
  State<ShimmerGlow> createState() => _ShimmerGlowState();
}

class _ShimmerGlowState extends State<ShimmerGlow>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = _controller.value * rect.width * 2 - rect.width;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [
                widget.color.withValues(alpha: 0),
                widget.color.withValues(alpha: 0.3),
                widget.color.withValues(alpha: 0),
              ],
              stops: [0.0, 0.5, 1.0],
              transform: GradientRotation(0),
            ).createShader(Rect.fromLTWH(dx, 0, rect.width, rect.height));
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

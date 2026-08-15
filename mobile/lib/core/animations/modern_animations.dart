import 'package:flutter/material.dart';

/// Animated count-up widget that smoothly counts from 0 to [target].
/// Great for dashboard stats, wallet balances, and earnings displays.
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.target,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.curve = Curves.easeOutCubic,
  });

  final double target;
  final String prefix;
  final String suffix;
  final int decimals;
  final Duration duration;
  final TextStyle? style;
  final Curve curve;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: widget.target).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.target,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        final value = _animation.value.toStringAsFixed(widget.decimals);
        return Text(
          '${widget.prefix}$value${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Bounce-in animation with elastic spring. Great for icons, avatars,
/// and hero elements that should feel playful on entrance.
class BounceIn extends StatefulWidget {
  const BounceIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
    this.beginScale = 0.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double beginScale;

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
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
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

/// Animated shimmer placeholder card. Use while loading data.
class ShimmerCard extends StatefulWidget {
  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.baseColor,
    this.highlightColor,
  });

  final double height;
  final double width;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
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
    final base = widget.baseColor ?? Colors.grey.shade300;
    final highlight = widget.highlightColor ?? Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            final dx = _controller.value * rect.width * 2 - rect.width;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(Rect.fromLTWH(dx, 0, rect.width, rect.height));
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// Slide-in from left with fade. Great for list items entering horizontally.
class SlideInLeft extends StatefulWidget {
  const SlideInLeft({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.distance = 0.3,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double distance;

  @override
  State<SlideInLeft> createState() => _SlideInLeftState();
}

class _SlideInLeftState extends State<SlideInLeft>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _slide = Tween<Offset>(
      begin: Offset(-widget.distance, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

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

/// Animated gradient header that subtly shifts colors over time.
/// Perfect for hero sections and app bars.
class AnimatedGradientHeader extends StatefulWidget {
  const AnimatedGradientHeader({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 4),
    this.borderRadius = 0,
  });

  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final double borderRadius;

  @override
  State<AnimatedGradientHeader> createState() => _AnimatedGradientHeaderState();
}

class _AnimatedGradientHeaderState extends State<AnimatedGradientHeader>
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
      builder: (_, child) {
        final t = _controller.value;
        final colors = List<Color>.from(widget.colors);
        // Shift colors by rotating the list proportionally
        final shifted = <Color>[];
        for (var i = 0; i < colors.length; i++) {
          final idx = (i + t * colors.length) % colors.length;
          final lower = idx.floor();
          final upper = (lower + 1) % colors.length;
          final frac = idx - lower;
          shifted.add(Color.lerp(colors[lower], colors[upper], frac)!);
        }
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: shifted,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: widget.borderRadius > 0
                ? BorderRadius.circular(widget.borderRadius)
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Tappable card with press-down scale animation and haptic feedback.
/// Wraps any child with a GestureDetector that scales on press.
class TappableScale extends StatefulWidget {
  const TappableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.95,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final bool haptic;

  @override
  State<TappableScale> createState() => _TappableScaleState();
}

class _TappableScaleState extends State<TappableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.haptic) {
          // Light haptic via system
          _controller.value = 0;
        }
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: scale,
        builder: (_, child) => Transform.scale(
          scale: scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

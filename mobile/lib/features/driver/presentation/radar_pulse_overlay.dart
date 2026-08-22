import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A radar pulse animation overlay for the driver map.
///
/// Renders concentric ripple rings expanding from the driver's location
/// pin to indicate active order polling. The rings fade out as they
/// expand, creating a sonar-like effect.
///
/// Place this as an overlay on top of the map widget at the driver's
/// current GPS coordinates.
class RadarPulseOverlay extends StatefulWidget {
  const RadarPulseOverlay({
    super.key,
    this.color = AppTheme.emerald,
    this.maxRadius = 120,
    this.pulseDuration = const Duration(milliseconds: 2000),
    this.ringCount = 3,
  });

  /// Color of the pulse rings.
  final Color color;

  /// Maximum radius of the expanding rings (in pixels).
  final double maxRadius;

  /// Duration of a single pulse cycle.
  final Duration pulseDuration;

  /// Number of concurrent rings (staggered).
  final int ringCount;

  @override
  State<RadarPulseOverlay> createState() => _RadarPulseOverlayState();
}

class _RadarPulseOverlayState extends State<RadarPulseOverlay>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.ringCount, (i) {
      return AnimationController(
        duration: widget.pulseDuration,
        vsync: this,
      );
    });

    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
      );
    }).toList();

    _opacityAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeIn),
      );
    }).toList();

    // Stagger the ring animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(
        Duration(milliseconds: (widget.pulseDuration.inMilliseconds ~/ widget.ringCount) * i),
        () {
          if (mounted) _controllers[i].repeat();
        },
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.maxRadius * 2,
      height: widget.maxRadius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(widget.ringCount, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, _) {
              final scale = _scaleAnimations[i].value;
              final opacity = _opacityAnimations[i].value;
              final radius = widget.maxRadius * scale;

              return Opacity(
                opacity: opacity,
                child: CustomPaint(
                  size: Size(radius * 2, radius * 2),
                  painter: _RadarRingPainter(
                    color: widget.color,
                    radius: radius,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Paints a single radar ring with a gradient stroke.
class _RadarRingPainter extends CustomPainter {
  _RadarRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.0)],
        stops: const [0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    // Inner fill (very subtle)
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);
  }

  @override
  bool shouldRepaint(_RadarRingPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}

/// A combined radar pulse + center pin widget. Place at the driver's
/// GPS position on the map.
class RadarPulseMarker extends StatelessWidget {
  const RadarPulseMarker({
    super.key,
    this.color = AppTheme.emerald,
    this.isActive = true,
  });

  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      // Static pin when not polling
      return _DriverPin(color: color, isPulsing: false);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Radar rings behind the pin
        const RadarPulseOverlay(maxRadius: 80),
        // Center pin on top
        _DriverPin(color: color, isPulsing: true),
      ],
    );
  }
}

/// The driver's location pin — a glowing dot with optional pulse.
class _DriverPin extends StatefulWidget {
  const _DriverPin({required this.color, required this.isPulsing});

  final Color color;
  final bool isPulsing;

  @override
  State<_DriverPin> createState() => _DriverPinState();
}

class _DriverPinState extends State<_DriverPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.isPulsing) _controller.repeat(reverse: true);
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
      builder: (context, _) {
        final glowOpacity = widget.isPulsing ? 0.3 + (_controller.value * 0.3) : 0.2;
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity),
                blurRadius: 12 + (_controller.value * 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

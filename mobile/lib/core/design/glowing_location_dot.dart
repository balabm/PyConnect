import 'dart:async';
import 'package:flutter/material.dart';

/// Uber-style glowing location dot with pulsating radius.
///
/// Layers:
/// 1. Translucent pulsating circle (radial gradient glow)
/// 2. Solid colored center dot
/// 3. White border ring
class GlowingLocationDot extends StatefulWidget {
  const GlowingLocationDot({
    super.key,
    this.color = const Color(0xFF10B981),
    this.size = 20,
    this.glowRadius = 60,
  });

  /// Color of the center dot and glow.
  final Color color;

  /// Diameter of the solid center dot.
  final double size;

  /// Maximum radius of the pulsating glow.
  final double glowRadius;

  @override
  State<GlowingLocationDot> createState() => _GlowingLocationDotState();
}

class _GlowingLocationDotState extends State<GlowingLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
      builder: (context, child) {
        // Pulse from 0.3 to 1.0 and back
        final pulse = (_controller.value * 3.14159).abs();
        final scale = 0.3 + 0.7 * (0.5 + 0.5 * (pulse / 3.14159));
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsating glow
            Container(
              width: widget.glowRadius * scale,
              height: widget.glowRadius * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.4 * (1 - _controller.value)),
                    widget.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // White border ring
            Container(
              width: widget.size + 4,
              height: widget.size + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            // Solid center dot
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}

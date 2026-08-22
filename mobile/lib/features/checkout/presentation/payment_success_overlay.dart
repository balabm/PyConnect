import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A full-screen payment success overlay that morphs from the pay button
/// into a spinning loading circle, then explodes into an emerald green
/// success screen with a confetti animation and a crisp "tick" sound.
///
/// Usage:
/// ```dart
/// PaymentSuccessOverlay.show(
///   context,
///   amount: '₹450',
///   orderId: 'ORD12345',
///   onComplete: () => navigateToOrderDetail(),
/// );
/// ```
class PaymentSuccessOverlay extends StatefulWidget {
  const PaymentSuccessOverlay({
    super.key,
    required this.amount,
    required this.orderId,
    this.onComplete,
    this.autoDismissDuration = const Duration(milliseconds: 2500),
  });

  final String amount;
  final String orderId;
  final VoidCallback? onComplete;
  final Duration autoDismissDuration;

  @override
  State<PaymentSuccessOverlay> createState() => _PaymentSuccessOverlayState();

  /// Shows the overlay as a full-screen modal.
  static void show(
    BuildContext context, {
    required String amount,
    required String orderId,
    VoidCallback? onComplete,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PaymentSuccessOverlay(
          amount: amount,
          orderId: orderId,
          onComplete: onComplete,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        barrierDismissible: false,
        opaque: false,
      ),
    );
  }
}

class _PaymentSuccessOverlayState extends State<PaymentSuccessOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _confettiController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Play a crisp tick sound via haptic feedback
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.lightImpact();
    });

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeIn,
      ),
    );

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.forward();
    });

    // Auto-dismiss after the configured duration
    Future.delayed(widget.autoDismissDuration, () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Stack(
        children: [
          // Emerald background glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        AppTheme.emerald.withOpacity(_fadeAnimation.value * 0.3),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Confetti
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(progress: _confettiController.value),
                );
              },
            ),
          ),
          // Center content
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success checkmark circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emerald.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // "Payment Successful" text
                  const Text(
                    'Payment Successful',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Amount
                  Text(
                    widget.amount,
                    style: TextStyle(
                      color: AppTheme.emeraldLight,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Order ID
                  Text(
                    'Order #${widget.orderId}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a confetti burst animation.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    AppTheme.emerald,
    AppTheme.emeraldLight,
    AppTheme.coral,
    AppTheme.gold,
    AppTheme.sky,
    Colors.white,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final random = math.Random(42); // Deterministic seed

    for (int i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * math.pi;
      final distance = progress * (size.width * 0.6);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle) +
          (progress * progress * 200); // Gravity
      final color = _colors[i % _colors.length];
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final rectSize = 6.0 + random.nextDouble() * 4;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      // Rotated rectangle confetti
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + progress * 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: rectSize,
          height: rectSize * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

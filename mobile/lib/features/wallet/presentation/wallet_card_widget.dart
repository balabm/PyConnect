import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_counter.dart';

/// A holographic digital card that represents the user's PY Wallet
/// balance as a physical-looking credit card.
///
/// Uses the device accelerometer to shift a subtle, semi-transparent
/// white linear gradient across the card as the user physically tilts
/// their phone, simulating light reflecting off a holographic surface.
class WalletCard extends StatefulWidget {
  const WalletCard({
    super.key,
    required this.balance,
    required this.cardHolder,
    this.cardNumber = '•••• •••• •••• PY01',
    this.gradient = AppTheme.emeraldGradient,
    this.onTap,
  });

  /// The wallet balance to display.
  final double balance;

  /// The card holder's name.
  final String cardHolder;

  /// The card number display string.
  final String cardNumber;

  /// The gradient for the card background.
  final Gradient gradient;

  /// Tap callback.
  final VoidCallback? onTap;

  @override
  State<WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends State<WalletCard> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  double _tiltX = 0.0; // Left/right tilt
  double _tiltY = 0.0; // Up/down tilt

  @override
  void initState() {
    super.initState();
    // Listen to accelerometer events for the holographic effect.
    // Update rate: 60ms (~16fps) to balance smoothness vs battery.
    _accelerometerSub =
        accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 60))
            .listen((event) {
      if (!mounted) return;
      setState(() {
        // Normalize accelerometer values to -1..1 range
        _tiltX = (event.x / 10).clamp(-1.0, 1.0);
        _tiltY = (event.y / 10).clamp(-1.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: widget.gradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.emerald.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Holographic gradient overlay (shifts with tilt)
              Positioned.fill(
                child: CustomPaint(
                  painter: _HolographicOverlayPainter(
                    tiltX: _tiltX,
                    tiltY: _tiltY,
                  ),
                ),
              ),
              // Card content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row: PY Connect logo + wallet icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PY Wallet',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        // Contactless payment icon
                        Icon(
                          Icons.contactless,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 28,
                        ),
                      ],
                    ),
                    // Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedCounter(
                          value: widget.balance,
                          prefix: '₹',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    // Bottom row: card number + holder
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.cardNumber,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          widget.cardHolder,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a holographic light reflection that shifts based on device tilt.
class _HolographicOverlayPainter extends CustomPainter {
  _HolographicOverlayPainter({required this.tiltX, required this.tiltY});

  final double tiltX;
  final double tiltY;

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the gradient center based on tilt
    // Tilt right -> light moves right, tilt left -> light moves left
    final centerX = size.width * 0.5 + (tiltX * size.width * 0.3);
    final centerY = size.height * 0.5 + (tiltY * size.height * 0.3);

    final gradient = RadialGradient(
      center: Alignment(
        (centerX / size.width) * 2 - 1,
        (centerY / size.height) * 2 - 1,
      ),
      radius: 0.8,
      colors: [
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: size.width,
          height: size.height,
        ),
      );

    canvas.drawRect(Offset.zero & size, paint);

    // Add a subtle diagonal sheen line
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(
          -1 + (tiltX * 0.5),
          -1 + (tiltY * 0.5),
        ),
        end: Alignment(
          1 + (tiltX * 0.5),
          1 + (tiltY * 0.5),
        ),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.4, 0.5, 0.6],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, sheenPaint);
  }

  @override
  bool shouldRepaint(_HolographicOverlayPainter oldDelegate) =>
      oldDelegate.tiltX != tiltX || oldDelegate.tiltY != tiltY;
}

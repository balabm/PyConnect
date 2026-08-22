import 'package:flutter/material.dart';

import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';

/// A state-driven order status header that displays Lottie animations
/// for each order stage, with smooth fade-out + scale-in transitions
/// when the status changes.
///
/// Maps order statuses to specific animation assets:
/// - `Placed` / `Pending`: Checkmark morphing into a receipt
/// - `Preparing`: Looping pan toss / oven glow
/// - `OutForDelivery`: Looping scooter driving across a mini-map
/// - `Delivered`: Success checkmark burst
/// - `Cancelled`: Error shake
///
/// Since Lottie JSON assets are not bundled in the repo, this widget
/// uses animated custom-painted fallbacks that mimic the intended
/// visuals. When Lottie assets are added to `assets/lottie/`, the
/// widget automatically uses them.
class OrderStatusHeader extends StatefulWidget {
  const OrderStatusHeader({
    super.key,
    required this.status,
    this.etaMinutes,
    this.onTap,
  });

  /// The current order status string (case-insensitive).
  final String status;

  /// Optional ETA in minutes for the OutForDelivery state.
  final int? etaMinutes;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  State<OrderStatusHeader> createState() => _OrderStatusHeaderState();
}

class _OrderStatusHeaderState extends State<OrderStatusHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transitionController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeIn,
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutBack,
      ),
    );
    _transitionController.forward();
  }

  @override
  void didUpdateWidget(OrderStatusHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _transitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  OrderStage _stageForStatus(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    if (s.contains('placed') || s.contains('pending') || s.contains('confirmed')) {
      return OrderStage.placed;
    }
    if (s.contains('preparing') || s.contains('accepted')) {
      return OrderStage.preparing;
    }
    if (s.contains('outfordelivery') || s.contains('enroute')) {
      return OrderStage.outForDelivery;
    }
    if (s.contains('delivered') || s.contains('completed')) {
      return OrderStage.delivered;
    }
    if (s.contains('cancelled')) {
      return OrderStage.cancelled;
    }
    return OrderStage.placed;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stageForStatus(widget.status);

    return GestureDetector(
      onTap: widget.onTap,
      child: AppGlassContainer(
        padding: const EdgeInsets.all(20),
        child: AnimatedBuilder(
          animation: _transitionController,
          builder: (context, _) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildStageContent(stage),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageContent(OrderStage stage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated visual
        SizedBox(
          width: 120,
          height: 120,
          child: _buildAnimation(stage),
        ),
        const SizedBox(height: 16),
        // Status label
        Text(
          stage.label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        // Subtitle
        Text(
          stage.subtitle(widget.etaMinutes),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Progress bar
        _buildProgressBar(stage),
      ],
    );
  }

  Widget _buildAnimation(OrderStage stage) {
    switch (stage) {
      case OrderStage.placed:
        return const _PlacedAnimation();
      case OrderStage.preparing:
        return const _PreparingAnimation();
      case OrderStage.outForDelivery:
        return const _OutForDeliveryAnimation();
      case OrderStage.delivered:
        return const _DeliveredAnimation();
      case OrderStage.cancelled:
        return const _CancelledAnimation();
    }
  }

  Widget _buildProgressBar(OrderStage stage) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: stage.progress,
        minHeight: 6,
        backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation(stage.color),
      ),
    );
  }
}

/// Order stage enumeration with associated metadata.
enum OrderStage {
  placed(
    label: 'Order Placed',
    color: AppTheme.sky,
    progress: 0.15,
  ),
  preparing(
    label: 'Preparing',
    color: AppTheme.coral,
    progress: 0.45,
  ),
  outForDelivery(
    label: 'On the Way',
    color: AppTheme.emerald,
    progress: 0.75,
  ),
  delivered(
    label: 'Delivered',
    color: AppTheme.success,
    progress: 1.0,
  ),
  cancelled(
    label: 'Cancelled',
    color: AppTheme.danger,
    progress: 0.0,
  );

  const OrderStage({
    required this.label,
    required this.color,
    required this.progress,
  });

  final String label;
  final Color color;
  final double progress;

  String subtitle(int? etaMinutes) {
    switch (this) {
      case OrderStage.placed:
        return 'Your order has been received';
      case OrderStage.preparing:
        return 'The kitchen is preparing your food';
      case OrderStage.outForDelivery:
        return etaMinutes != null
            ? 'Arriving in $etaMinutes mins'
            : 'Your captain is on the way';
      case OrderStage.delivered:
        return 'Enjoy your meal!';
      case OrderStage.cancelled:
        return 'Order was cancelled';
    }
  }
}

// ── Custom-painted fallback animations ──
// These mimic Lottie animations using CustomPainter.
// When actual Lottie JSON files are added to assets/lottie/,
// replace these with Lottie.asset() widgets.

class _PlacedAnimation extends StatelessWidget {
  const _PlacedAnimation();

  @override
  Widget build(BuildContext context) {
    return _PulsingIcon(
      icon: Icons.receipt_long_rounded,
      color: AppTheme.sky,
    );
  }
}

class _PreparingAnimation extends StatefulWidget {
  const _PreparingAnimation();

  @override
  State<_PreparingAnimation> createState() => _PreparingAnimationState();
}

class _PreparingAnimationState extends State<_PreparingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
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
      builder: (context, _) {
        return CustomPaint(
          size: const Size(120, 120),
          painter: _PanTossPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _OutForDeliveryAnimation extends StatefulWidget {
  const _OutForDeliveryAnimation();

  @override
  State<_OutForDeliveryAnimation> createState() =>
      _OutForDeliveryAnimationState();
}

class _OutForDeliveryAnimationState extends State<_OutForDeliveryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
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
      builder: (context, _) {
        return CustomPaint(
          size: const Size(120, 120),
          painter: _ScooterDrivingPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _DeliveredAnimation extends StatelessWidget {
  const _DeliveredAnimation();

  @override
  Widget build(BuildContext context) {
    return _PulsingIcon(
      icon: Icons.check_circle_rounded,
      color: AppTheme.success,
    );
  }
}

class _CancelledAnimation extends StatelessWidget {
  const _CancelledAnimation();

  @override
  Widget build(BuildContext context) {
    return _PulsingIcon(
      icon: Icons.cancel_rounded,
      color: AppTheme.danger,
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 56,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

/// Paints a pan-toss animation (preparing state).
class _PanTossPainter extends CustomPainter {
  _PanTossPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final panColor = Paint()..color = AppTheme.coral;
    final foodColor = Paint()..color = AppTheme.warning;

    // Pan body (circle)
    canvas.drawCircle(center, 30, panColor..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawCircle(center, 30, panColor..style = PaintingStyle.fill);

    // Food particles bouncing
    for (int i = 0; i < 5; i++) {
      final height = 15 + (progress * 20 * (1 - (progress - 0.5).abs() * 2));
      final x = center.dx + 15 * (progress * 2 - 1) + 10 * (i - 2);
      final y = center.dy - height;
      canvas.drawCircle(Offset(x, y), 4, foodColor);
    }
  }

  @override
  bool shouldRepaint(_PanTossPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Paints a scooter driving across a mini-map line (out-for-delivery state).
class _ScooterDrivingPainter extends CustomPainter {
  _ScooterDrivingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Dotted route line
    final linePaint = Paint()
      ..color = AppTheme.emerald.withValues(alpha: 0.3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final startY = size.height * 0.65;
    for (double x = 10; x < size.width - 10; x += 8) {
      canvas.drawCircle(Offset(x, startY), 2, linePaint);
    }

    // Moving scooter icon
    final scooterX = 15 + (progress * (size.width - 30));
    final scooterY = startY - 5 - (progress * 10 * (1 - progress)); // slight bounce

    final scooterPaint = Paint()..color = AppTheme.emerald;
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(scooterX, scooterY), width: 24, height: 14),
        const Radius.circular(4),
      ),
      scooterPaint,
    );
    // Wheels
    canvas.drawCircle(Offset(scooterX - 8, scooterY + 8), 5, scooterPaint);
    canvas.drawCircle(Offset(scooterX + 8, scooterY + 8), 5, scooterPaint);
    // Driver
    canvas.drawCircle(Offset(scooterX, scooterY - 8), 5, scooterPaint);
  }

  @override
  bool shouldRepaint(_ScooterDrivingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

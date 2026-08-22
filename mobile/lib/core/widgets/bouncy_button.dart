import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A button with spring physics micro-interaction.
///
/// On tap down, the button scales to 0.96x. On tap up/cancel, it
/// springs back to 1.0x using [Curves.easeOutBack] (150ms).
/// Triggers [HapticFeedback.lightImpact()] on every tap.
///
/// Wrap any primary action button (`[ Pay Now ]`, `[ Accept Order ]`,
/// `[ Go Online ]`) with this widget for a tactile, premium feel.
class BouncyButton extends StatefulWidget {
  const BouncyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleDown = 0.96,
    this.springDuration = const Duration(milliseconds: 150),
    this.haptic = true,
    this.hapticType = HapticType.light,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration springDuration;
  final bool haptic;
  final HapticType hapticType;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

enum HapticType { light, selection, medium, heavy, success, error, warning }

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.springDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    _triggerHaptic();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _triggerHaptic() {
    if (!widget.haptic) return;
    switch (widget.hapticType) {
      case HapticType.light:
        HapticFeedback.lightImpact();
      case HapticType.selection:
        HapticFeedback.selectionClick();
      case HapticType.medium:
        HapticFeedback.mediumImpact();
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
      case HapticType.success:
        HapticFeedback.heavyImpact();
        HapticFeedback.lightImpact();
      case HapticType.error:
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      case HapticType.warning:
        HapticFeedback.mediumImpact();
        HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bouncy_button.dart';

/// A floating cart summary pill that overlays the bottom of the screen.
///
/// Replaces the static bottom checkout bar with a premium floating pill:
/// `[ 3 Items • ₹650 | Checkout ]`. Triggers a bouncy scale animation
/// and haptic tick whenever an item is added to the cart.
class FloatingCartPill extends StatefulWidget {
  const FloatingCartPill({
    super.key,
    required this.itemCount,
    required this.subtotal,
    required this.onCheckout,
  });

  final int itemCount;
  final double subtotal;
  final VoidCallback onCheckout;

  @override
  State<FloatingCartPill> createState() => _FloatingCartPillState();
}

class _FloatingCartPillState extends State<FloatingCartPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  int _previousItemCount = 0;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.easeOutBack,
      ),
    );
    _previousItemCount = widget.itemCount;
  }

  @override
  void didUpdateWidget(FloatingCartPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce + haptic when an item is added
    if (widget.itemCount > _previousItemCount) {
      _bounceController.forward().then((_) => _bounceController.reverse());
      HapticFeedback.selectionClick();
    }
    _previousItemCount = widget.itemCount;
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: child,
          );
        },
        child: BouncyButton(
          onTap: widget.onCheckout,
          hapticType: HapticType.medium,
          child: Container(
            decoration: AppDecorations.floatingPill(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Item count badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald,
                    shape: BoxShape.circle,
                    boxShadow: AppDecorations.coloredGlow(AppTheme.emerald),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Items + price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.itemCount} ${widget.itemCount == 1 ? "Item" : "Items"}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.slate,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${widget.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppTheme.charcoal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkout button
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.emeraldGradient,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Checkout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../cart_conflict_exception.dart';

/// A bottom sheet that warns the user when they try to add an item from a
/// different vendor than what's already in their cart.
///
/// Shows the current vendor name, the new vendor name, and provides two
/// actions: "Keep Current Cart" (dismisses) and "Discard & Start Fresh"
/// (clears the cart and adds the new item).
class CartCollisionSheet {
  CartCollisionSheet._();

  /// Shows the collision sheet. Returns `true` if the user chose to discard
  /// the current cart and start fresh, `false` (or null) if they kept it.
  static Future<bool?> show(BuildContext context, CartConflictException conflict) {
    AppHaptics.medium();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CollisionSheetContent(conflict: conflict),
    );
  }
}

class _CollisionSheetContent extends StatelessWidget {
  const _CollisionSheetContent({required this.conflict});
  final CartConflictException conflict;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Warning icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: AppTheme.warning,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cart Conflict',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your cart contains items from ${conflict.vendorName}. '
            'Do you want to discard them and start a new order with ${conflict.newVendorName}?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Keep Current Cart — grey
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                AppHaptics.light();
                Navigator.pop(context, false);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Keep Current Cart',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Discard & Start Fresh — red
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                AppHaptics.error();
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Discard & Start Fresh',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

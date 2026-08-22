import 'package:flutter/material.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';

/// A celebratory bottom sheet that pops up the moment a trip is completed.
///
/// Shows a fully transparent earnings breakdown so the driver can see exactly
/// how much the customer paid, the 0% platform commission, and their final
/// earnings. PY Connect takes 0% commission — drivers keep 100%.
///
/// The sheet is non-dismissible ([isDismissible: false]) to ensure the driver
/// always sees their earnings summary before returning to the task pool.
class PostTripSummarySheet extends StatelessWidget {
  const PostTripSummarySheet({
    super.key,
    required this.customerPaid,
    required this.driverEarnings,
    this.tripType = 'Ride',
    this.paymentMethod,
    this.onDone,
  });

  /// The total amount the customer paid for the trip (fare / order total).
  final double customerPaid;

  /// The driver's earnings. Since PY Connect takes 0% commission, this is
  /// always equal to [customerPaid].
  final double driverEarnings;

  /// The type of trip — 'Ride' or 'Food Delivery'. Used to customize the
  /// celebratory icon and subtitle.
  final String tripType;

  /// Optional payment method label (e.g. 'Cash', 'UPI'). If provided, a
  /// payment-method chip is shown so the driver knows how they were paid.
  final String? paymentMethod;

  /// Callback invoked when the driver taps the "Done" button. Typically
  /// navigates back to the Tasks/Radar screen.
  final VoidCallback? onDone;

  /// Shows the [PostTripSummarySheet] as a modal bottom sheet.
  ///
  /// The sheet is non-dismissible and non-draggable to ensure the driver
  /// always sees their earnings before continuing.
  static Future<void> show(
    BuildContext context, {
    required double customerPaid,
    required double driverEarnings,
    String tripType = 'Ride',
    String? paymentMethod,
    VoidCallback? onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PostTripSummarySheet(
        customerPaid: customerPaid,
        driverEarnings: driverEarnings,
        tripType: tripType,
        paymentMethod: paymentMethod,
        onDone: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidStr = customerPaid.toStringAsFixed(0);
    final earningsStr = driverEarnings.toStringAsFixed(0);
    final isFood = tripType.toLowerCase().contains('food') ||
        tripType.toLowerCase().contains('delivery');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Celebratory icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFood ? Icons.celebration : Icons.check_circle,
              color: AppTheme.emerald,
              size: 52,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Trip Completed!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.emerald,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isFood ? 'Food delivery delivered successfully' : 'Ride completed successfully',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Big earnings number
          Text(
            '\u20B9$earningsStr',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Earnings (100%)',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Payment method chip (if provided)
          if (paymentMethod != null && paymentMethod!.isNotEmpty) ...[
            _PaymentChip(paymentMethod: paymentMethod!),
            const SizedBox(height: 20),
          ],

          // Earnings breakdown card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                FareRow(
                  label: 'Customer Paid',
                  value: '\u20B9$paidStr',
                  small: true,
                ),
                const SizedBox(height: 8),
                FareRow(
                  label: 'Platform Commission (0%)',
                  value: '\u20B90',
                  small: true,
                  valueColor: AppTheme.emerald,
                ),
                const Divider(height: 24),
                FareRow(
                  label: 'Your Earnings',
                  value: '\u20B9$earningsStr',
                  bold: true,
                  valueColor: AppTheme.emerald,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 0% commission badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings, color: AppTheme.emerald, size: 18),
                const SizedBox(width: 8),
                Text(
                  'PY Connect takes 0% commission — you keep 100%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AppHaptics.success();
                onDone?.call();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Done'),
              style: FilledButton.styleFrom(foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small chip showing the payment method (Cash / UPI / Online).
class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.paymentMethod});
  final String paymentMethod;

  @override
  Widget build(BuildContext context) {
    final isCash = paymentMethod.toLowerCase() == 'cash';
    final color = isCash ? AppTheme.warning : AppTheme.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCash ? Icons.payments : Icons.account_balance_wallet,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isCash ? 'Cash' : 'Paid Online via UPI',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

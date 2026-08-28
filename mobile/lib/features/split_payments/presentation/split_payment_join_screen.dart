import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../data/split_payment_api.dart';

/// Split Payment Join screen.
///
/// When a friend clicks a deep-link URL like `pyconnect.run.place/split/abcd123`,
/// they land here. The screen shows the pool details (description, total amount,
/// per-share amount, progress bar), lets them claim a share, and then pay via
/// Razorpay UPI.
class SplitPaymentJoinScreen extends ConsumerStatefulWidget {
  const SplitPaymentJoinScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<SplitPaymentJoinScreen> createState() =>
      _SplitPaymentJoinScreenState();
}

class _SplitPaymentJoinScreenState
    extends ConsumerState<SplitPaymentJoinScreen> {
  SplitPaymentPoolModel? _pool;
  bool _loading = true;
  bool _claiming = false;
  bool _paying = false;
  String? _error;
  bool _hasClaimed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPool());
  }

  Future<void> _loadPool() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pool = await ref.read(splitPaymentApiProvider).getBySlug(widget.slug);
      if (!mounted) return;
      setState(() {
        _pool = pool;
        _loading = false;
        // Check if current user already claimed
        _hasClaimed = pool.contributors.any((c) => c.isPaid);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load split payment. The link may be invalid or expired.';
        _loading = false;
      });
    }
  }

  Future<void> _claimAndPay() async {
    final pool = _pool;
    if (pool == null) return;

    AppHaptics.light();
    setState(() {
      _claiming = true;
      _error = null;
    });

    try {
      await ref.read(splitPaymentApiProvider).claimShare(pool.id);
      if (!mounted) return;
      setState(() => _claiming = false);

      // Now initiate Razorpay payment
      _initiateRazorpay(pool);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _claiming = false;
        _error = 'Failed to claim share. You may have already claimed it.';
      });
    }
  }

  Future<void> _initiateRazorpay(SplitPaymentPoolModel pool) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    setState(() => _paying = true);

    try {
      // Create a Razorpay order for the per-share amount via the backend.
      final order = await paymentService.createOrder(
        amount: pool.perShareAmount,
      );

      if (!mounted) return;

      // Open Razorpay checkout.
      final paymentResult = await paymentService
          .startPayment(
            orderId: order.providerOrderId,
            amount: (pool.perShareAmount * 100).round(), // paise
            phone: authSession?.phone ?? '',
            userName: authSession?.name,
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => PaymentError(
              code: -1,
              message: 'Payment timed out. Please try again.',
            ),
          );

      if (!mounted) return;
      setState(() => _paying = false);

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          // Verify payment signature on backend, then mark share as paid.
          final verified = await paymentService.verifyPayment(
            paymentId: order.paymentId,
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
          );

          if (!mounted) return;

          if (verified) {
            // Call the split-payments pay endpoint with Razorpay IDs.
            await ref.read(splitPaymentApiProvider).payShare(
                  poolId: pool.id,
                  razorpayOrderId: orderId,
                  razorpayPaymentId: paymentId,
                  razorpaySignature: signature ?? '',
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment of ₹${pool.perShareAmount.toStringAsFixed(0)} completed!'),
                backgroundColor: AppTheme.success,
              ),
            );
            _loadPool(); // Refresh to show updated progress
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment verification failed. Please contact support.'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }

        case PaymentError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.danger,
            ),
          );

        case PaymentExternalWallet():
          _loadPool();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _pool != null
                  ? _buildPoolDetails(_pool!)
                  : const Center(child: Text('Pool not found')),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolDetails(SplitPaymentPoolModel pool) {
    return RefreshIndicator(
      onRefresh: _loadPool,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Description card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pool.description,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildRow('Total Amount', '₹${pool.totalAmount.toStringAsFixed(0)}'),
                  _buildRow('Your Share', '₹${pool.perShareAmount.toStringAsFixed(0)}'),
                  _buildRow('Shares', '${pool.claimedShares}/${pool.maxShares}'),
                  _buildRow('Status', pool.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collected: ₹${pool.collectedAmount.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text('${(pool.progress * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: pool.progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Contributors list
          if (pool.contributors.isNotEmpty) ...[
            Text('Contributors', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...pool.contributors.map((c) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.isPaid ? AppTheme.success : AppTheme.warning,
                    child: Icon(c.isPaid ? Icons.check : Icons.hourglass_empty,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(c.name),
                  subtitle: Text('₹${c.shareAmount.toStringAsFixed(0)} — ${c.status}'),
                  dense: true,
                )),
            const SizedBox(height: 16),
          ],

          // Action button
          if (pool.isActive && pool.sharesLeft > 0 && !_hasClaimed)
            FilledButton.icon(
              onPressed: _claiming || _paying ? null : _claimAndPay,
              icon: _claiming || _paying
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment),
              label: Text(_claiming
                  ? 'Claiming share...'
                  : _paying
                      ? 'Processing payment...'
                      : 'Claim & Pay ₹${pool.perShareAmount.toStringAsFixed(0)}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else if (pool.isFullyPaid)
            Card(
              color: AppTheme.success.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success),
                    SizedBox(width: 12),
                    Expanded(child: Text('All shares paid! The booking is confirmed.')),
                  ],
                ),
              ),
            )
          else if (pool.sharesLeft == 0)
            Card(
              color: AppTheme.warning.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.group, color: AppTheme.warning),
                    SizedBox(width: 12),
                    Expanded(child: Text('All shares have been claimed.')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.slate)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

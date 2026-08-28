import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../data/subscription_api.dart';

final subscriptionApiProvider = Provider<SubscriptionApi>((ref) {
  return SubscriptionApi(ref.watch(apiClientProvider));
});

final primeStatusProvider = FutureProvider<PrimeStatusModel>((ref) async {
  return ref.watch(subscriptionApiProvider).getStatus();
});

/// PY Prime subscription screen — shows benefits, current status, and
/// Razorpay checkout for activation.
class PrimeScreen extends ConsumerStatefulWidget {
  const PrimeScreen({super.key});

  @override
  ConsumerState<PrimeScreen> createState() => _PrimeScreenState();
}

class _PrimeScreenState extends ConsumerState<PrimeScreen> {
  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(primeStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('PY Prime')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('Could not load Prime status', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(primeStatusProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (status) => RefreshIndicator(
          onRefresh: () async => ref.refresh(primeStatusProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (status.isPrime) _buildActiveCard(status),
              if (status.isPrime) const SizedBox(height: 24),
              _buildHeroCard(status),
              const SizedBox(height: 28),
              _buildBenefitsSection(),
              const SizedBox(height: 28),
              _buildPlanCard(status),
              const SizedBox(height: 24),
              if (!status.isPrime) _buildSubscribeButton(status),
              if (status.isPrime) _buildManageSection(status),
              const SizedBox(height: 32),
              _buildFaqSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(PrimeStatusModel status) {
    final expiry = status.expiresAt != null
        ? DateTime.tryParse(status.expiresAt!)
        : null;
    final expiryText = expiry != null
        ? '${expiry.day}/${expiry.month}/${expiry.year}'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: AppTheme.emerald, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PY Prime Active',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  status.inGracePeriod
                      ? 'Grace period: $status.gracePeriodDays days left'
                      : 'Renews on $expiryText',
                  style: TextStyle(
                    fontSize: 13,
                    color: status.inGracePeriod ? AppTheme.warning : AppTheme.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(PrimeStatusModel status) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PY PRIME',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock Premium Benefits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '\u20B9${status.monthlyPrice.toStringAsFixed(0)}/month',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cancel anytime',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = [
      ('Free delivery on food orders', Icons.delivery_dining, 'No delivery fee on orders above \u20B9200'),
      ('15% off all rides', Icons.local_taxi, 'Discount on every ride, every day'),
      ('Priority dispatch', Icons.flash_on, 'Skip the queue during peak hours'),
      ('Exclusive event access', Icons.event, 'Early access and member-only events'),
      ('2x PY Coins', Icons.stars, 'Earn double coins on every transaction'),
      ('Free cancellations', Icons.cancel, 'No cancellation fees on rides and orders'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prime Benefits',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...benefits.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(b.$2, color: AppTheme.gold, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          b.$3,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPlanCard(PrimeStatusModel status) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Monthly Plan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'Billed monthly. Cancel anytime.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            '\u20B9${status.monthlyPrice.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.gold),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(PrimeStatusModel status) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _purchasing ? null : () => _purchasePrime(status),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.gold,
        ),
        child: _purchasing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Subscribe to PY Prime',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildManageSection(PrimeStatusModel status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Subscription', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            'Your PY Prime subscription is active and will auto-renew. '
            'To cancel, visit your Razorpay dashboard or contact support.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    final faqs = [
      ('Can I cancel anytime?', 'Yes. Cancel from your Razorpay dashboard or by contacting support. Benefits continue until the end of the billing period.'),
      ('When am I billed?', 'You are billed monthly on the date you subscribed. The first charge happens immediately.'),
      ('Do benefits apply to all services?', 'Yes. Free delivery, ride discounts, and 2x coins apply across all PY Connect services.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FAQ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...faqs.map((f) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )),
      ],
    );
  }

  Future<void> _purchasePrime(PrimeStatusModel status) async {
    if (_purchasing) return;
    AppHaptics.light();
    setState(() => _purchasing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Create a Razorpay order for the subscription.
      final orderResult = await ref.read(subscriptionApiProvider).createOrder();

      // 2. Launch Razorpay checkout.
      final paymentService = ref.read(razorpayPaymentProvider);
      final authSession = ref.read(authControllerProvider).valueOrNull;
      paymentService.init();

      final paymentResult = await paymentService
          .startPayment(
            orderId: orderResult.razorpayOrderId,
            amount: (orderResult.amount * 100).round(),
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

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId):
          try {
            await ref.read(subscriptionApiProvider).activate(paymentId);
            ref.invalidate(primeStatusProvider);
            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Welcome to PY Prime! Benefits are now active.'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Payment succeeded but activation failed: $e'),
                  backgroundColor: AppTheme.danger,
                ),
              );
            }
          }
        case PaymentError(:final message):
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text('Payment failed: $message'), backgroundColor: AppTheme.danger),
            );
          }
        case PaymentExternalWallet():
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Payment via wallet. Please verify your subscription.'),
                backgroundColor: AppTheme.info,
              ),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Subscription failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }
}

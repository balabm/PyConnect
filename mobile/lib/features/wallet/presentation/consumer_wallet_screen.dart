import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../auth/application/auth_controller.dart';
import '../data/user_wallet_api.dart';
import 'wallet_card_widget.dart';

/// A premium consumer wallet screen with holographic card, rolling
/// balance animations, and transaction history.
///
/// This is a UI shell — the wallet provider should be wired to the
/// backend wallet API when available.
class ConsumerWalletScreen extends ConsumerStatefulWidget {
  const ConsumerWalletScreen({super.key});

  @override
  ConsumerState<ConsumerWalletScreen> createState() =>
      _ConsumerWalletScreenState();
}

class _ConsumerWalletScreenState extends ConsumerState<ConsumerWalletScreen> {
  UserWalletModel? _wallet;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wallet = await ref.read(userWalletApiProvider).getWallet();
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  double get _balance => _wallet?.totalBalance ?? 0;
  int get _pyCoins => _wallet?.pyCoins.round() ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PY Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddMoneySheet(context),
            tooltip: 'Add Money',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 12),
                      Text('Could not load wallet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loadWallet,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWallet,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Holographic wallet card
                        WalletCard(
                          balance: _balance,
                          cardHolder: 'PY Member',
                        ),
                        const SizedBox(height: 24),
                        // Quick actions row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _QuickAction(
                              icon: Icons.add_rounded,
                              label: 'Add Money',
                              onTap: () => _showAddMoneySheet(context),
                            ),
                            _QuickAction(
                              icon: Icons.send_rounded,
                              label: 'Send',
                              onTap: () {},
                            ),
                            _QuickAction(
                              icon: Icons.receipt_long_rounded,
                              label: 'History',
                              onTap: () {},
                            ),
                            _QuickAction(
                              icon: Icons.account_balance_rounded,
                              label: 'Bank',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // PY Coins section
                        _buildCoinsSection(isDark),
                        const SizedBox(height: 24),
                        // Recent transactions
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTransactionList(isDark),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCoinsSection(bool isDark) {
    return AppModernCard(
      padding: const EdgeInsets.all(20),
      glowColor: AppTheme.gold,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PY Coins',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.slate,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AnimatedCounter(
                  value: _pyCoins.toDouble(),
                  suffix: ' coins',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.charcoal,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppDecorations.statusBadge(context, AppTheme.gold),
            child: Text(
              'Silver',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(bool isDark) {
    // Transaction history endpoint is planned for a future iteration.
    // For now, show an honest empty state.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.slate.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Transaction history coming soon',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMoneySheet(BuildContext context) {
    double selectedAmount = 500;
    final customAmountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Money to Wallet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Top up via Razorpay. Funds are credited instantly after payment.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.slate.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              // Quick amount chips
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [200, 500, 1000, 2000].map((amount) {
                  final isSelected = selectedAmount == amount.toDouble();
                  return ChoiceChip(
                    label: Text('\u20B9$amount'),
                    selected: isSelected,
                    onSelected: (_) {
                      setSheetState(() {
                        selectedAmount = amount.toDouble();
                        customAmountController.clear();
                      });
                    },
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.emerald,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Custom amount
              TextField(
                controller: customAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Or enter custom amount',
                  prefixText: '\u20B9 ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    setSheetState(() => selectedAmount = parsed);
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _processTopUp(selectedAmount);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.emerald,
                  ),
                  child: Text(
                    'Add \u20B9${selectedAmount.toStringAsFixed(0)} via Razorpay',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processTopUp(double amount) async {
    if (amount <= 0) return;
    AppHaptics.light();

    try {
      // 1. Create Razorpay order via backend
      final initResult = await ref.read(userWalletApiProvider).initiateTopUp(amount);

      // 2. Launch Razorpay checkout
      final paymentService = ref.read(razorpayPaymentProvider);
      final authSession = ref.read(authControllerProvider).valueOrNull;
      paymentService.init();

      final paymentResult = await paymentService
          .startPayment(
            orderId: initResult.razorpayOrderId,
            amount: (amount * 100).round(),
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
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          try {
            final updatedWallet = await ref.read(userWalletApiProvider).confirmTopUp(
                  amount: amount,
                  razorpayOrderId: orderId,
                  razorpayPaymentId: paymentId,
                  signature: signature ?? '',
                );
            if (mounted) {
              setState(() => _wallet = updatedWallet);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('\u20B9${amount.toStringAsFixed(0)} added to wallet!'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment succeeded but confirmation failed: $e'),
                  backgroundColor: AppTheme.danger,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        case PaymentError(:final message):
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $message'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment via wallet. Please verify your balance.'),
                backgroundColor: AppTheme.info,
              ),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Top-up failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: AppTheme.emerald, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.slate,
            ),
          ),
        ],
      ),
    );
  }
}

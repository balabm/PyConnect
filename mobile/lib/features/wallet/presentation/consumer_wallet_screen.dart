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
  List<UserWalletTransactionModel>? _transactions;
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ref.read(userWalletApiProvider).getWallet(),
        ref.read(userWalletApiProvider).getTransactions(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as UserWalletModel;
          _transactions = results[1] as List<UserWalletTransactionModel>;
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
                    controller: _scrollController,
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
                              onTap: () => _showSendSheet(context),
                            ),
                            _QuickAction(
                              icon: Icons.receipt_long_rounded,
                              label: 'History',
                              onTap: () {
                                _scrollController.animateTo(
                                  _scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                            _QuickAction(
                              icon: Icons.account_balance_rounded,
                              label: 'Bank',
                              onTap: () => _showBankSheet(context),
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
    final transactions = _transactions;

    if (transactions == null || transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.slate.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.slate.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Top up your wallet to get started',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.slate.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isCredit = tx.isCredit;
        final iconData = isCredit ? Icons.add_circle : Icons.remove_circle;
        final iconColor = isCredit ? AppTheme.emerald : AppTheme.danger;

        return ListTile(
          leading: Icon(iconData, color: iconColor),
          title: Text(
            tx.description,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            tx.type,
            style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.6)),
          ),
          trailing: Text(
            '${isCredit ? '+' : '-'}\u20B9${tx.amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        );
      },
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

  void _showSendSheet(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool sending = false;

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
          child: Form(
            key: formKey,
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
                  'Send Money',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transfer from your wallet to another PY Connect user by phone number.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slate.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Recipient phone number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                    hintText: '9876543210',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\u20B9 ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    if (_wallet != null && parsed > _wallet!.realBalance) {
                      return 'Insufficient real balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: sending
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => sending = true);
                            AppHaptics.light();
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(ctx);
                            try {
                              final updated = await ref
                                  .read(userWalletApiProvider)
                                  .transfer(
                                    recipientPhone: phoneCtrl.text.trim(),
                                    amount: double.parse(amountCtrl.text),
                                  );
                              if (mounted) {
                                navigator.pop();
                                setState(() => _wallet = updated);
                                await _loadWallet();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '\u20B9${amountCtrl.text} sent successfully!'),
                                    backgroundColor: AppTheme.emerald,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Transfer failed: $e'),
                                    backgroundColor: AppTheme.danger,
                                  ),
                                );
                                setSheetState(() => sending = false);
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.emerald,
                    ),
                    child: sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Money',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBankSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: AppTheme.emerald, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Bank Account',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Link your bank account to withdraw wallet balance directly to your bank. '
              'Bank verification requires KYC completion.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.slate.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bank withdrawals are rolling out soon. '
                      'You can still use your wallet balance for rides, food, and bookings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.slate.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(sheetContext),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
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

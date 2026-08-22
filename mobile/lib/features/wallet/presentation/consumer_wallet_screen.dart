import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_counter.dart';
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
  // Placeholder balance — wire to backend wallet provider
  double _balance = 1250.00;

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
      body: SingleChildScrollView(
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
                colors: [AppTheme.gold, AppTheme.gold.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withOpacity(0.3),
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
                  value: 340,
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
    final transactions = [
      _Transaction('Food Order - Fuoco', -450, 'Pizza Margherita', Icons.restaurant),
      _Transaction('Ride - White Town', -85, 'Auto ride', Icons.two_wheeler),
      _Transaction('Wallet Top-up', 1000, 'UPI Payment', Icons.account_balance),
      _Transaction('Cashback Reward', 50, 'PY Coins redemption', Icons.redeem),
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isCredit = tx.amount > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppModernCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isCredit ? AppTheme.emerald : AppTheme.coral)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tx.icon,
                    color: isCredit ? AppTheme.emerald : AppTheme.coral,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.charcoal,
                        ),
                      ),
                      Text(
                        tx.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCounter(
                  value: tx.amount,
                  prefix: isCredit ? '+₹' : '−₹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? AppTheme.emerald : AppTheme.coral,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMoneySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Money to Wallet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Quick amount chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [200, 500, 1000, 2000].map((amount) {
                return ActionChip(
                  label: Text('₹$amount'),
                  onPressed: () {
                    setState(() => _balance += amount);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
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
              color: AppTheme.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.emerald.withOpacity(0.15),
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

class _Transaction {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;

  _Transaction(this.title, this.amount, this.subtitle, this.icon);
}

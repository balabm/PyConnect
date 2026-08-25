import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Bank-grade financial ledger screen for vendors.
///
/// Shows the vendor's available withdrawal balance, credit balance, total
/// platform fees paid, bank account KYC status, and a chronological ledger
/// of every credit/deit entry. Supports pull-to-refresh and one-tap
/// withdrawal to a verified bank account with a 10% TDS deduction.
class VendorFinanceScreen extends ConsumerStatefulWidget {
  const VendorFinanceScreen({super.key});

  @override
  ConsumerState<VendorFinanceScreen> createState() =>
      _VendorFinanceScreenState();
}

class _VendorFinanceScreenState extends ConsumerState<VendorFinanceScreen> {
  Map<String, dynamic>? _wallet;
  Object? _error;
  bool _isLoading = true;
  bool _isWithdrawing = false;

  @override
  void initState() {
    super.initState();
    // Defer to after first frame so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final data = await api.getDetailedWallet();
      if (!mounted) return;
      setState(() {
        _wallet = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleWithdraw() async {
    final wallet = _wallet;
    if (wallet == null) return;

    final available =
        (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
    if (available <= 0) return;

    final isBankVerified = wallet['isBankVerified'] as bool? ?? false;
    if (!isBankVerified) return;

    AppHaptics.light();

    final tds = available * 0.10;
    final net = available - tds;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to withdraw your available balance to your linked bank account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _confirmRow(context, 'Withdrawal Amount',
                _formatCurrency(available), AppTheme.emerald),
            _confirmRow(context, 'TDS Deduction (10%)',
                '- ${_formatCurrency(tds)}', AppTheme.danger),
            const Divider(height: 24),
            _confirmRow(context, 'Net Payout', _formatCurrency(net),
                AppTheme.charcoal, isBold: true),
            const SizedBox(height: 12),
            Text(
              'The NEFT transfer typically settles within 1-2 business hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.light();
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AppHaptics.light();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isWithdrawing = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.requestWithdrawal(available);
      final netAmount =
          (result['netAmount'] as num?)?.toDouble() ?? net;
      AppHaptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Withdrawal initiated. Net payout ${_formatCurrency(netAmount)} will settle shortly.'),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadWallet();
    } catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Withdrawal failed: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isWithdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Finance & Ledger'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              _loadWallet();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.emerald,
        onRefresh: _loadWallet,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.emerald),
      );
    }

    if (_error != null) {
      return _buildError(context);
    }

    final wallet = _wallet;
    if (wallet == null) {
      return _buildError(context);
    }

    final available =
        (wallet['availableBalance'] as num?)?.toDouble() ?? 0.0;
    final credit =
        (wallet['creditBalance'] as num?)?.toDouble() ?? 0.0;
    final feesPaid =
        (wallet['platformFeesPaid'] as num?)?.toDouble() ?? 0.0;
    final isBankVerified = wallet['isBankVerified'] as bool? ?? false;
    final bankAccount =
        wallet['bankAccountNumber'] as String? ?? '';
    final bankIfsc = wallet['bankIfsc'] as String? ?? '';
    final bankName = wallet['bankAccountName'] as String? ?? '';
    final ledgerEntries = (wallet['ledgerEntries'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildSummaryCard(
          context,
          available: available,
          credit: credit,
          feesPaid: feesPaid,
          isBankVerified: isBankVerified,
          bankAccount: bankAccount,
          bankIfsc: bankIfsc,
          bankName: bankName,
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildWithdrawalSection(context, available, isBankVerified),
        const SizedBox(height: AppSpacing.xxl),
        _buildSectionHeader(context, 'Ledger'),
        if (ledgerEntries.isEmpty)
          _buildEmptyLedger(context)
        else
          ...ledgerEntries.map((e) => _LedgerEntryCard(entry: e)),
      ],
    );
  }

  // ── Wallet Summary Card ──

  Widget _buildSummaryCard(
    BuildContext context, {
    required double available,
    required double credit,
    required double feesPaid,
    required bool isBankVerified,
    required String bankAccount,
    required String bankIfsc,
    required String bankName,
  }) {
    final last4 = bankAccount.length >= 4
        ? bankAccount.substring(bankAccount.length - 4)
        : bankAccount;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Available for Withdrawal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatCurrency(available),
            style: TextStyle(
              color: AppTheme.emerald,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _summaryStat(
                  context,
                  label: 'Credit Balance',
                  value: _formatCurrency(credit),
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _summaryStat(
                  context,
                  label: 'Platform Fees Paid',
                  value: _formatCurrency(feesPaid),
                  color: AppTheme.slate,
                  isSmall: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          _buildBankStatus(
            context,
            isBankVerified: isBankVerified,
            last4: last4,
            bankIfsc: bankIfsc,
            bankName: bankName,
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isSmall = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isSmall ? 16 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBankStatus(
    BuildContext context, {
    required bool isBankVerified,
    required String last4,
    required String bankIfsc,
    required String bankName,
  }) {
    final color = isBankVerified ? AppTheme.emerald : AppTheme.warning;
    final icon = isBankVerified ? Icons.verified : Icons.warning_amber_rounded;
    final label = isBankVerified ? 'Verified' : 'Not Verified';

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (last4.isNotEmpty) ...[
          Text(
            '•••• $last4',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (bankIfsc.isNotEmpty)
            Text(
              '  $bankIfsc',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
        const Spacer(),
        if (bankName.isNotEmpty)
          Flexible(
            child: Text(
              bankName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
    );
  }

  // ── Withdrawal Section ──

  Widget _buildWithdrawalSection(
    BuildContext context,
    double available,
    bool isBankVerified,
  ) {
    final disabled = !isBankVerified || available <= 0 || _isWithdrawing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isBankVerified)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppTheme.warning, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Complete KYC to enable withdrawals',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isBankVerified) const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppTheme.emerald.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: disabled ? null : _handleWithdraw,
            icon: _isWithdrawing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.account_balance, size: 20),
            label: Text(
              _isWithdrawing
                  ? 'Processing...'
                  : 'Withdraw to Bank',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger Section ──

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildEmptyLedger(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No ledger entries yet',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ──

  Widget _buildError(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Could not load wallet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error?.toString() ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () {
                    AppHaptics.light();
                    _loadWallet();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  Widget _confirmRow(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              fontSize: isBold ? 18 : 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntryCard extends StatelessWidget {
  const _LedgerEntryCard({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final type = (entry['type'] as String?) ?? '';
    final isCredit =
        type.toLowerCase() == 'credit' || type.toLowerCase() == 'in';
    final color = isCredit ? AppTheme.emerald : AppTheme.danger;
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final description = (entry['description'] as String?) ?? '';
    final dateStr = (entry['date'] as String?) ??
        (entry['timestamp'] as String?) ??
        (entry['createdAt'] as String?) ??
        '';

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.2)
                : AppTheme.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                isCredit ? Icons.add_rounded : Icons.remove_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(type, isCredit),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(dateStr),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${isCredit ? '+' : '-'}${_formatCurrency(amount)}',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type, bool isCredit) {
    if (type.isEmpty) return isCredit ? 'CREDIT' : 'DEBIT';
    return type.toUpperCase();
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) {
      return iso;
    }
  }
}

/// Formats a number as Indian currency: ₹X,XX,XXX
String _formatCurrency(double amount) {
  final isNegative = amount < 0;
  final absValue = amount.abs();
  final parts = absValue.toStringAsFixed(0).split('.');
  final intPart = parts[0];

  // Indian grouping: last 3 digits, then groups of 2.
  final chars = intPart.split('').reversed.toList();
  final groups = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (i == 0) {
      groups.add(chars[i]);
    } else if (i < 3) {
      groups[0] = chars[i] + groups[0];
    } else {
      final groupIndex = (i - 3) ~/ 2 + 1;
      if (groups.length <= groupIndex) {
        groups.add(chars[i]);
      } else {
        groups[groupIndex] = chars[i] + groups[groupIndex];
      }
    }
  }
  final formatted = groups.reversed.join(',');

  final result = '₹$formatted';
  return isNegative ? '-$result' : result;
}

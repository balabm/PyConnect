import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/providers.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../auth/application/auth_controller.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';

final driverEarningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.getDriverEarnings();
});

final driverWithdrawalsProvider = FutureProvider<List<DriverWithdrawalModel>>((ref) async {
  final api = ref.watch(driverApiProvider);
  return await api.getWithdrawals();
});

class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(driverEarningsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () {
          AppHaptics.light();
          return ref.refresh(driverEarningsProvider.future);
        },
        child: earningsAsync.when(
          loading: () => const ShimmerList(withImage: false, count: 5),
          error: (e, _) => EmptyStateView(
            isError: true,
            icon: Icons.cloud_off_rounded,
            title: 'Something went wrong',
            subtitle: e.toString(),
            actionLabel: 'Retry Connection',
            onAction: () => ref.invalidate(driverEarningsProvider),
          ),
          data: (data) => _EarningsBody(data: data),
        ),
      ),
    );
  }
}

class _EarningsBody extends ConsumerWidget {
  const _EarningsBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayEarnings = data['todayEarnings'] ?? 0;
    final weekEarnings = data['weekEarnings'] ?? 0;
    final monthEarnings = data['monthEarnings'] ?? 0;
    final todayRides = data['todayRides'] ?? 0;
    final weekRides = data['weekRides'] ?? 0;
    final monthRides = data['monthRides'] ?? 0;
    final avgRating = (data['avgRating'] as num?)?.toDouble() ?? 5.0;
    final recentRides = data['recentRides'] as List<dynamic>? ?? [];
    final isOnline = ref.watch(driverOnlineStatusProvider);
    final hasEarnings = (todayEarnings as num) > 0 ||
        (weekEarnings as num) > 0 ||
        (monthEarnings as num) > 0 ||
        (todayRides as num) > 0 ||
        (weekRides as num) > 0 ||
        (monthRides as num) > 0 ||
        recentRides.isNotEmpty;

    if (!isOnline || !hasEarnings) {
      return EmptyStateView(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No Earnings Yet',
        subtitle: 'Complete tasks to see your daily summary here.',
        actionLabel: 'Start Browsing Tasks',
        onAction: () => ref.read(driverSelectedTabProvider.notifier).state = 0,
      );
    }

    // Fetch driver profile for the profile section
    final profileAsync = ref.watch(driverProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cash-collection wallet card
          const _WalletCard(),
          const SizedBox(height: 16),
          // Today's earnings - big card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Today\'s Earnings', style: TextStyle(color: AppTheme.emerald, fontSize: 14)),
                const SizedBox(height: 8),
                Text('\u20B9$todayEarnings', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car, color: AppTheme.emerald, size: 16),
                    const SizedBox(width: 4),
                    Text('$todayRides rides today', style: const TextStyle(color: AppTheme.emerald)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Week & Month stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'This Week',
                  earnings: '\u20B9$weekEarnings',
                  rides: '$weekRides rides',
                  icon: Icons.calendar_view_week,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'This Month',
                  earnings: '\u20B9$monthEarnings',
                  rides: '$monthRides rides',
                  icon: Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rating card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: AppTheme.gold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                RatingStars(rating: avgRating, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 0% commission banner
          AppCard(
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.savings, color: AppTheme.emerald, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('0% Commission', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('100% of ride fare goes to you. No hidden cuts.', style: TextStyle(color: AppTheme.emerald, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Recent rides
          const Text('Recent Rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (recentRides.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No completed rides yet',
              subtitle: 'Your completed rides will appear here',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentRides.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final ride = recentRides[index] as Map<String, dynamic>;
                final earnings = ride['earnings'] ?? 0;
                final distance = ride['distanceKm'] ?? 0;
                final duration = ride['durationMin'] ?? 0;
                final completedAt = ride['completedAt'] as String? ?? '';
                final rideId = ride['rideId'] as String? ?? ride['id'] as String?;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                  title: Text('\u20B9$earnings', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$distance km · $duration min · ${_formatDate(completedAt)}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Icon(Icons.receipt_long, color: AppTheme.emerald.withValues(alpha: 0.6), size: 20),
                    ],
                  ),
                  onTap: () => _showReceipt(context, ref, rideId, ride),
                );
              },
            ),
          const SizedBox(height: 24),
          // Profile section with actual driver data
          const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Driver info from profile
                profileAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        _ProfileInfoRow(label: 'Name', value: profile.name),
                        _ProfileInfoRow(label: 'Phone', value: profile.phone),
                        _ProfileInfoRow(label: 'Vehicle', value: profile.vehicleType),
                        if (profile.vehiclePlate != null && profile.vehiclePlate!.isNotEmpty)
                          _ProfileInfoRow(label: 'Plate', value: profile.vehiclePlate!),
                        _ProfileInfoRow(label: 'Rating', value: avgRating.toStringAsFixed(1)),
                        const Divider(),
                      ],
                    );
                  },
                ),
                _ProfileTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'KYC Documents',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.security_outlined,
                  title: 'Safety Settings',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'Help & Support',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _WithdrawalHistory(),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  /// Shows a receipt detail dialog for a completed ride.
  /// Falls back to the data already in the recent rides list if the
  /// receipt API call fails.
  void _showReceipt(BuildContext context, WidgetRef ref, String? rideId, Map<String, dynamic> ride) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ReceiptDialog(rideId: rideId, ride: ride);
      },
    );
  }
}

/// Dialog showing ride receipt details.
class _ReceiptDialog extends ConsumerStatefulWidget {
  const _ReceiptDialog({required this.rideId, required this.ride});
  final String? rideId;
  final Map<String, dynamic> ride;

  @override
  ConsumerState<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends ConsumerState<_ReceiptDialog> {
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    if (widget.rideId == null) {
      // No ride ID — use the data we already have
      setState(() { _loading = false; });
      return;
    }
    try {
      final api = ref.read(ridesApiProvider);
      final receipt = await api.getReceipt(widget.rideId!);
      if (mounted) setState(() { _receipt = receipt; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _receipt ?? widget.ride;
    final earnings = data['earnings'] ?? data['driverEarnings'] ?? data['totalAmount'] ?? 0;
    final distance = data['distanceKm'] ?? data['distance'] ?? 0;
    final duration = data['durationMin'] ?? data['duration'] ?? 0;
    final completedAt = data['completedAt'] as String? ?? data['createdAt'] as String? ?? '';
    final pickup = data['pickupAddress'] as String? ?? 'N/A';
    final dropoff = data['dropoffAddress'] as String? ?? 'N/A';
    final vehicleType = data['vehicleType'] as String? ?? '';
    final paymentMethod = data['paymentMethod'] as String? ?? '';

    return AlertDialog(
      title: const Text('Ride Receipt'),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReceiptRow(label: 'Earnings', value: '\u20B9$earnings'),
                  _ReceiptRow(label: 'Distance', value: '$distance km'),
                  _ReceiptRow(label: 'Duration', value: '$duration min'),
                  if (vehicleType.isNotEmpty) _ReceiptRow(label: 'Vehicle', value: vehicleType),
                  if (paymentMethod.isNotEmpty) _ReceiptRow(label: 'Payment', value: paymentMethod),
                  _ReceiptRow(label: 'Pickup', value: pickup),
                  _ReceiptRow(label: 'Dropoff', value: dropoff),
                  _ReceiptRow(label: 'Completed', value: _formatDate(completedAt)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Detailed receipt unavailable. Showing summary.', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.earnings, required this.rides, required this.icon});
  final String title;
  final String earnings;
  final String rides;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 4),
          Text(earnings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(rides, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.emerald),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
    );
  }
}

/// Cash-collection wallet card showing balance, suspended status, warning,
/// settle-dues button, and recent wallet transactions.
class _WalletCard extends ConsumerStatefulWidget {
  const _WalletCard();

  @override
  ConsumerState<_WalletCard> createState() => _WalletCardState();
}

class _WalletCardState extends ConsumerState<_WalletCard> {
  bool _settling = false;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(driverWalletDetailProvider);

    return walletAsync.when(
      loading: () => AppCard(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.wallet_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Wallet unavailable', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          ],
        ),
      ),
      data: (wallet) => _buildWalletContent(wallet),
    );
  }

  Widget _buildWalletContent(DriverWalletDetailModel wallet) {
    final isNegative = wallet.balance < 0;
    final balanceColor = isNegative ? Colors.red : AppTheme.emerald;
    final settleAmount = wallet.settleAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance card
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 8),
                  const Text('Cash Collection Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  if (wallet.suspended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Suspended', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '${wallet.balance < 0 ? '-' : ''}\u20B9${wallet.balance.abs().toStringAsFixed(2)}',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: balanceColor),
              ),
              const SizedBox(height: 4),
              Text(
                isNegative
                    ? 'You owe the platform \u20B9${settleAmount.toStringAsFixed(2)} in COD commission'
                    : 'No outstanding dues',
                style: TextStyle(fontSize: 12, color: isNegative ? Colors.red : AppTheme.slate),
              ),
              // Warning when approaching hard limit
              if (wallet.isApproachingHardLimit && !wallet.suspended) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Warning: Your wallet is approaching the suspension limit (\u20B9${wallet.hardLimit.toStringAsFixed(0)}). Settle soon to avoid going offline.',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ],
              // Settle Dues button
              if (settleAmount > 0) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _settling ? null : () => _settleDues(wallet, settleAmount),
                    icon: _settling
                        ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                        : const Icon(Icons.payment),
                    label: Text(_settling ? 'Processing...' : 'Settle Dues \u20B9${settleAmount.toStringAsFixed(2)}'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              // Withdraw to Bank button
              if (!wallet.suspended && wallet.balance > 100) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showWithdrawSheet(wallet.balance),
                    icon: const Icon(Icons.account_balance),
                    label: const Text('Withdraw to Bank'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Recent wallet transactions
        if (wallet.recentTransactions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Wallet Transactions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final txn in wallet.recentTransactions.take(8))
                  _WalletTransactionTile(txn: txn),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Opens a confirmation bottom sheet where the captain can enter an amount
  /// and confirm a wallet withdrawal to their linked UPI/bank.
  void _showWithdrawSheet(double balance) {
    AppHaptics.light();
    final profileAsyncValue = ref.read(driverProfileProvider);
    final profile = profileAsyncValue.valueOrNull;
    final upiId = profile?.upiId;
    final bankAccount = profile?.bankAccountNumber;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _WithdrawalSheet(
          balance: balance,
          upiId: upiId,
          bankAccount: bankAccount,
          onConfirm: (amount) async {
            Navigator.pop(sheetContext);
            try {
              final api = ref.read(driverApiProvider);
              await api.requestWithdrawal(amount);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Withdrawal request of \u20B9${amount.toStringAsFixed(2)} submitted.')),
                );
                ref.invalidate(driverWalletDetailProvider);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Withdrawal failed: $e')),
                );
              }
            }
          },
        );
      },
    );
  }

  /// Initiates Razorpay checkout for the settle amount, then verifies the
  /// payment on the backend to credit the wallet.
  Future<void> _settleDues(DriverWalletDetailModel wallet, double amount) async {
    AppHaptics.light();
    setState(() => _settling = true);

    try {
      final api = ref.read(driverApiProvider);
      final paymentService = ref.read(razorpayPaymentProvider);
      final authSession = ref.read(authControllerProvider).valueOrNull;

      // 1. Create a Razorpay order via the wallet topup endpoint
      final order = await api.initiateTopUp(amount);

      if (!mounted) return;

      // 2. Open Razorpay checkout
      final paymentResult = await paymentService
          .startPayment(
            orderId: order.orderId,
            amount: (amount * 100).round(), // paise
            phone: authSession?.phone ?? '',
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
          // 3. Verify the payment and credit the wallet
          final verified = await api.verifyTopUp(
            amount: amount,
            paymentId: paymentId,
            orderId: orderId,
            signature: signature,
          );
          if (mounted) {
            if (verified) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dues settled successfully! Wallet credited.')),
              );
              ref.invalidate(driverWalletDetailProvider);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment verification failed. Please contact support.')),
              );
            }
          }
        case PaymentError(:final message):
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('External wallet selected. Please complete payment.')),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settlement failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }
}

/// Bottom sheet used to enter and confirm a wallet withdrawal amount.
class _WithdrawalSheet extends StatefulWidget {
  const _WithdrawalSheet({
    required this.balance,
    required this.upiId,
    required this.bankAccount,
    required this.onConfirm,
  });

  final double balance;
  final String? upiId;
  final String? bankAccount;
  final ValueChanged<double> onConfirm;

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  late final TextEditingController _amountController;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.balance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _amountController.text;
    final amount = double.tryParse(amountText) ?? 0;
    final remaining = widget.balance - amount;
    final isValid = amount >= 100 && amount <= widget.balance;

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomPadding + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: SizedBox(
              width: 40,
              child: Divider(thickness: 4, height: 24),
            ),
          ),
          const Text('Withdraw to Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (widget.bankAccount != null && widget.bankAccount!.isNotEmpty)
            _InfoRow(label: 'Bank Account', value: widget.bankAccount!),
          if (widget.upiId != null && widget.upiId!.isNotEmpty)
            _InfoRow(label: 'UPI ID', value: widget.upiId!),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (\u20B9)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Remaining balance: \u20B9${remaining.toStringAsFixed(2)}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _confirming ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirming || !isValid
                      ? null
                      : () {
                          setState(() => _confirming = true);
                          widget.onConfirm(amount);
                        },
                  child: _confirming
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// A single wallet transaction row (commission deduction, top-up, etc.).
class _WalletTransactionTile extends StatelessWidget {
  const _WalletTransactionTile({required this.txn});
  final WalletTransactionModel txn;

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.amount >= 0;
    final icon = isCredit ? Icons.add_circle : Icons.remove_circle;
    final color = isCredit ? AppTheme.emerald : Colors.red;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        txn.description,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${txn.type} · ${_formatDate(txn.createdAt)}',
        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        '${isCredit ? '+' : ''}\u20B9${txn.amount.abs().toStringAsFixed(2)}',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

/// Shows the driver's withdrawal history, newest first.
class _WithdrawalHistory extends ConsumerWidget {
  const _WithdrawalHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final withdrawalsAsync = ref.watch(driverWithdrawalsProvider);

    return withdrawalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (withdrawals) {
        if (withdrawals.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdrawal History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final w in withdrawals.take(10))
                    _WithdrawalHistoryTile(withdrawal: w),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WithdrawalHistoryTile extends StatelessWidget {
  const _WithdrawalHistoryTile({required this.withdrawal});
  final DriverWithdrawalModel withdrawal;

  @override
  Widget build(BuildContext context) {
    final color = withdrawal.status == 'Rejected'
        ? Colors.red
        : withdrawal.status == 'Processed'
            ? AppTheme.emerald
            : Colors.orange;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(Icons.account_balance_wallet, color: color, size: 20),
      title: Text(
        '\u20B9${withdrawal.amount.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${withdrawal.status} · ${_formatDate(withdrawal.requestedAt)}',
        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        withdrawal.status,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

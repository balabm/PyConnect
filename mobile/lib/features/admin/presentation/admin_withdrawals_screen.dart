import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_api.dart';

final adminWithdrawalsProvider =
    FutureProvider<List<AdminWithdrawalRequest>>((ref) async {
  final api = ref.watch(adminApiProvider);
  return await api.getWithdrawals();
});

/// Admin screen for managing driver withdrawal requests.
/// Lists pending and processed withdrawals with approve/reject actions.
class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() =>
      _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState
    extends ConsumerState<AdminWithdrawalsScreen> {
  String _filter = 'All';

  static const _statuses = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    final withdrawalsAsync = ref.watch(adminWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Withdrawals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminWithdrawalsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _statuses.map((status) {
                final isSelected = _filter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (_) {
                      AppHaptics.light();
                      setState(() => _filter = status);
                    },
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.emerald,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: withdrawalsAsync.when(
              data: (withdrawals) {
                final filtered = _filter == 'All'
                    ? withdrawals
                    : withdrawals.where((w) => w.status == _filter).toList();
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminWithdrawalsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final w = filtered[index];
                      return _WithdrawalCard(
                        withdrawal: w,
                        onApprove: () => _approve(w),
                        onReject: () => _reject(w),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(AdminWithdrawalRequest w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Withdrawal?'),
        content: Text('Approve \u20B9${w.amount.toStringAsFixed(0)} withdrawal for ${w.driverName}? This will transfer funds to their account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;
    AppHaptics.success();
    try {
      await ref.read(adminApiProvider).approveWithdrawal(w.id);
      ref.invalidate(adminWithdrawalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved \u20B9${w.amount.toStringAsFixed(0)} for ${w.driverName}'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _reject(AdminWithdrawalRequest w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Withdrawal?'),
        content: Text('Reject \u20B9${w.amount.toStringAsFixed(0)} withdrawal request from ${w.driverName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    AppHaptics.warning();
    try {
      await ref.read(adminApiProvider).rejectWithdrawal(w.id);
      ref.invalidate(adminWithdrawalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected withdrawal for ${w.driverName}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payments_outlined, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No withdrawal requests',
            style: TextStyle(fontSize: 16, color: AppTheme.slate.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text('Could not load withdrawals', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => ref.invalidate(adminWithdrawalsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({
    required this.withdrawal,
    required this.onApprove,
    required this.onReject,
  });

  final AdminWithdrawalRequest withdrawal;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isPending = withdrawal.status == 'Pending';
    final statusColor = switch (withdrawal.status) {
      'Pending' => AppTheme.gold,
      'Approved' => AppTheme.emerald,
      'Rejected' => AppTheme.danger,
      _ => AppTheme.slate,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    withdrawal.driverName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    withdrawal.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\u20B9${withdrawal.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.emerald),
            ),
            const SizedBox(height: 8),
            if (withdrawal.bankAccount.isNotEmpty)
              Text(
                'A/C: ${withdrawal.bankAccount}  IFSC: ${withdrawal.ifsc}',
                style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.7)),
              ),
            if (withdrawal.requestedAt.isNotEmpty)
              Text(
                'Requested: ${withdrawal.requestedAt}',
                style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.5)),
              ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

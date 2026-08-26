import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_api.dart';

final invoicesProvider = FutureProvider<List<AdminTaxInvoice>>((ref) async {
  return ref.watch(adminApiProvider).getInvoices();
});

final payoutsProvider =
    FutureProvider.family<List<AdminPayout>, String?>((ref, status) async {
  return ref.watch(adminApiProvider).getPayouts(status: status);
});

final chargebacksProvider =
    FutureProvider.family<List<AdminChargeback>, String?>((ref, status) async {
  return ref.watch(adminApiProvider).getChargebacks(status: status);
});

/// Admin finance management screen with tabs for Invoices, Payouts, and Chargebacks.
class AdminFinanceManagementScreen extends ConsumerStatefulWidget {
  const AdminFinanceManagementScreen({super.key});

  @override
  ConsumerState<AdminFinanceManagementScreen> createState() =>
      _AdminFinanceManagementScreenState();
}

class _AdminFinanceManagementScreenState
    extends ConsumerState<AdminFinanceManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
            Tab(icon: Icon(Icons.payments), text: 'Payouts'),
            Tab(icon: Icon(Icons.gavel), text: 'Chargebacks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _InvoicesTab(),
          _PayoutsTab(),
          _ChargebacksTab(),
        ],
      ),
    );
  }
}

// ── Invoices Tab ──

class _InvoicesTab extends ConsumerStatefulWidget {
  const _InvoicesTab();

  @override
  ConsumerState<_InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends ConsumerState<_InvoicesTab> {
  bool _generating = false;

  Future<void> _generateInvoices() async {
    final now = DateTime.now();
    AppHaptics.light();
    setState(() => _generating = true);
    try {
      final result = await ref.read(adminApiProvider).generateInvoices(
            year: now.year,
            month: now.month,
          );
      ref.invalidate(invoicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${result.invoiceCount} invoices for ${result.year}-${result.month}'),
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
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generating ? null : _generateInvoices,
                  icon: _generating
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_generating ? 'Generating...' : 'Generate Monthly Invoices'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: invoicesAsync.when(
            data: (invoices) {
              if (invoices.isEmpty) {
                return _buildEmpty('No invoices generated yet', Icons.receipt_long_outlined);
              }
              return ListView.builder(
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final inv = invoices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(Icons.receipt, color: AppTheme.emerald),
                      title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Month: ${inv.invoiceMonth} \u00B7 ${inv.transactionCount} txns'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\u20B9${inv.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (inv.isEmailed)
                            const Icon(Icons.mark_email_read, size: 14, color: AppTheme.emerald)
                          else
                            const Icon(Icons.mark_email_unread, size: 14, color: AppTheme.slate),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildError(e.toString()),
          ),
        ),
      ],
    );
  }
}

// ── Payouts Tab ──

class _PayoutsTab extends ConsumerStatefulWidget {
  const _PayoutsTab();

  @override
  ConsumerState<_PayoutsTab> createState() => _PayoutsTabState();
}

class _PayoutsTabState extends ConsumerState<_PayoutsTab> {
  String? _statusFilter;
  bool _processing = false;

  static const _statuses = [null, 'Pending', 'Processed', 'Failed'];

  Future<void> _processSettlements() async {
    AppHaptics.light();
    setState(() => _processing = true);
    try {
      final result = await ref.read(adminApiProvider).processSettlements();
      ref.invalidate(payoutsProvider(_statusFilter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processed ${result.vendorPayouts} vendor + ${result.driverPayouts} driver payouts'),
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
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payoutsAsync = ref.watch(payoutsProvider(_statusFilter));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _processSettlements,
                  icon: _processing
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow),
                  label: Text(_processing ? 'Processing...' : 'Process Pending Settlements'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _statuses.map((s) {
              final isSelected = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s ?? 'All'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.emerald,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: payoutsAsync.when(
            data: (payouts) {
              if (payouts.isEmpty) return _buildEmpty('No payout requests', Icons.payments_outlined);
              return ListView.builder(
                itemCount: payouts.length,
                itemBuilder: (context, index) {
                  final p = payouts[index];
                  final statusColor = switch (p.status) {
                    'Processed' => AppTheme.emerald,
                    'Failed' => AppTheme.danger,
                    _ => AppTheme.gold,
                  };
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(p.recipientType == 'Driver' ? Icons.directions_car : Icons.store, color: AppTheme.emerald),
                      title: Text('${p.recipientType} \u00B7 \u20B9${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Net: \u20B9${p.netAmount.toStringAsFixed(0)} (TDS: \u20B9${p.tdsDeducted.toStringAsFixed(0)})\n${p.utrNumber != null ? 'UTR: ${p.utrNumber}' : p.failureReason ?? 'Awaiting processing'}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(p.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildError(e.toString()),
          ),
        ),
      ],
    );
  }
}

// ── Chargebacks Tab ──

class _ChargebacksTab extends ConsumerStatefulWidget {
  const _ChargebacksTab();

  @override
  ConsumerState<_ChargebacksTab> createState() => _ChargebacksTabState();
}

class _ChargebacksTabState extends ConsumerState<_ChargebacksTab> {
  String? _statusFilter;

  static const _statuses = [null, 'Open', 'Won', 'Lost', 'Resolved'];

  Future<void> _resolveChargeback(AdminChargeback cb, bool won) async {
    AppHaptics.light();
    try {
      await ref.read(adminApiProvider).resolveChargeback(cb.id, won: won);
      ref.invalidate(chargebacksProvider(_statusFilter));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chargeback ${won ? 'won' : 'lost'}'),
            backgroundColor: won ? AppTheme.emerald : AppTheme.danger,
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

  @override
  Widget build(BuildContext context) {
    final chargebacksAsync = ref.watch(chargebacksProvider(_statusFilter));
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _statuses.map((s) {
              final isSelected = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s ?? 'All'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.emerald,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: chargebacksAsync.when(
            data: (chargebacks) {
              if (chargebacks.isEmpty) return _buildEmpty('No chargeback disputes', Icons.gavel_outlined);
              return ListView.builder(
                itemCount: chargebacks.length,
                itemBuilder: (context, index) {
                  final cb = chargebacks[index];
                  final isOpen = cb.status == 'Open';
                  final statusColor = switch (cb.status) {
                    'Won' => AppTheme.emerald,
                    'Lost' => AppTheme.danger,
                    'Resolved' => AppTheme.emerald,
                    _ => AppTheme.gold,
                  };
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Chargeback \u20B9${cb.chargebackAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(cb.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Order: ${cb.orderType ?? 'N/A'} \u00B7 Payment: ${cb.paymentId.substring(0, 8)}...'),
                          if (cb.accountFrozen)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(children: [
                                Icon(Icons.ac_unit, size: 14, color: AppTheme.danger),
                                SizedBox(width: 4),
                                Text('Account frozen', style: TextStyle(fontSize: 12, color: AppTheme.danger)),
                              ]),
                            ),
                          if (cb.evidenceSummary != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Evidence: ${cb.evidenceSummary}', style: const TextStyle(fontSize: 12)),
                            ),
                          if (isOpen) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _resolveChargeback(cb, true),
                                    style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
                                    child: const Text('Mark Won'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _resolveChargeback(cb, false),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                                    child: const Text('Mark Lost'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildError(e.toString()),
          ),
        ),
      ],
    );
  }
}

Widget _buildEmpty(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(fontSize: 16, color: AppTheme.slate.withValues(alpha: 0.7))),
      ],
    ),
  );
}

Widget _buildError(String error) {
  return Builder(builder: (context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text('Could not load data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(error, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  });
}

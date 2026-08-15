import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

/// Finance & Audit screen for the PY Connect admin "God Mode" dashboard.
///
/// Surfaces key financial metrics for the platform:
///  - GMV (Gross Merchandise Value) across all completed payments
///  - Commission Revenue (platform take-rate; currently 0% — drivers keep 100%)
///  - Driver Payouts Due (pending settlements)
///  - Razorpay Settlement Log (recent settlement entries)
///
/// Data is fetched from GET /api/admin/finance/summary and
/// GET /api/admin/finance/settlements.
class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  ConsumerState<AdminFinanceScreen> createState() =>
      _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminFinanceSummaryProvider);
    ref.invalidate(adminSettlementsProvider);
  }

  String _formatRupees(double amount) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');
    return fmt.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminFinanceSummaryProvider);
    final settlementsAsync = ref.watch(adminSettlementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance & Audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AdminColors.accent,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Metric cards
            summaryAsync.when(
              data: (summary) => LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 900 ? 3 : 1;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth - (crossCount - 1) * 16) /
                            crossCount,
                        child: _FinanceMetricCard(
                          icon: Icons.payments_rounded,
                          label: 'GMV (GROSS MERCHANDISE VALUE)',
                          value: _formatRupees(summary.gmv),
                          subtitle:
                              '${summary.totalTransactions} completed payments',
                          color: AdminColors.accent,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - (crossCount - 1) * 16) /
                            crossCount,
                        child: _FinanceMetricCard(
                          icon: Icons.savings_rounded,
                          label: 'COMMISSION REVENUE',
                          value: _formatRupees(summary.commissionRevenue),
                          subtitle:
                              '0% — drivers keep 100%',
                          color: AdminColors.info,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - (crossCount - 1) * 16) /
                            crossCount,
                        child: _FinanceMetricCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'DRIVER PAYOUTS DUE',
                          value: _formatRupees(summary.driverPayoutsDue),
                          subtitle: 'Pending settlements',
                          color: AdminColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AdminColors.accent),
                ),
              ),
              error: (e, _) => _FinanceError(
                message: 'Could not load finance summary',
                onRetry: _refresh,
              ),
            ),
            const SizedBox(height: 32),
            // Razorpay settlement log
            settlementsAsync.when(
              data: (settlements) => _SettlementLogSection(
                entries: settlements,
                onRefresh: _refresh,
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AdminColors.accent),
                ),
              ),
              error: (e, _) => _FinanceError(
                message: 'Could not load settlement log',
                onRetry: _refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric card
// ---------------------------------------------------------------------------

class _FinanceMetricCard extends StatelessWidget {
  const _FinanceMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AdminColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Razorpay settlement log table
// ---------------------------------------------------------------------------

class _SettlementLogSection extends StatelessWidget {
  const _SettlementLogSection({required this.entries, required this.onRefresh});

  final List<AdminSettlementLog> entries;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AdminColors.accent),
                const SizedBox(width: 8),
                const Text(
                  'Razorpay Settlement Log',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length} entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No settlements yet',
                    style: TextStyle(color: AdminColors.textMuted, fontSize: 14),
                  ),
                ),
              )
            else
              Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _SettlementTable(entries: entries),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettlementTable extends StatefulWidget {
  const _SettlementTable({required this.entries});
  final List<AdminSettlementLog> entries;

  @override
  State<_SettlementTable> createState() => _SettlementTableState();
}

class _SettlementTableState extends State<_SettlementTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  List<AdminSettlementLog> get _sorted {
    final list = List<AdminSettlementLog>.from(widget.entries);
    list.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = (a.capturedAt).compareTo(b.capturedAt);
        case 1:
          cmp = a.amount.compareTo(b.amount);
        case 2:
          cmp = a.status.compareTo(b.status);
        default:
          final aRef = a.providerPaymentId.isNotEmpty
              ? a.providerPaymentId
              : a.paymentId;
          final bRef = b.providerPaymentId.isNotEmpty
              ? b.providerPaymentId
              : b.paymentId;
          cmp = aRef.compareTo(bRef);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 24,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      columns: [
        DataColumn(
          label: const Text('Date',
              style: TextStyle(
                  color: AdminColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('Amount',
              style: TextStyle(
                  color: AdminColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          numeric: true,
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('Status',
              style: TextStyle(
                  color: AdminColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('Reference ID',
              style: TextStyle(
                  color: AdminColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
      ],
      rows: _sorted.map((e) {
        final statusLower = e.status.toLowerCase();
        final color = statusLower == 'captured' || statusLower == 'succeeded'
            ? AdminColors.success
            : statusLower == 'pending' || statusLower == 'processing'
                ? AdminColors.warning
                : AdminColors.danger;
        return DataRow(
          cells: [
            DataCell(Text(
              e.capturedAt.isNotEmpty
                  ? e.capturedAt.substring(0, e.capturedAt.length > 10 ? 10 : e.capturedAt.length)
                  : '—',
              style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
            )),
            DataCell(Text(
              '\u20B9${e.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            )),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.status.isNotEmpty ? e.status : 'Unknown',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )),
            DataCell(Text(
              e.providerPaymentId.isNotEmpty ? e.providerPaymentId : e.paymentId,
              style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
            )),
          ],
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error widget
// ---------------------------------------------------------------------------

class _FinanceError extends StatelessWidget {
  const _FinanceError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AdminColors.textMuted),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AdminColors.textMuted, fontSize: 14)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AdminColors.accent),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

/// Finance & Audit screen for the PY Connect admin "God Mode" dashboard.
///
/// Surfaces key financial metrics for the platform:
///  - GMV (Gross Merchandise Value) across all completed payments
///  - Commission Revenue (platform take-rate; currently 0% — drivers keep 100%)
///  - Driver Payouts Due (pending settlements)
///  - Razorpay Settlement Log (recent settlement entries)
///
/// All values are mock/placeholder for now — TODO comments mark where the
/// backend wiring should be added once the finance endpoints are available.
class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  ConsumerState<AdminFinanceScreen> createState() =>
      _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  /// Last-updated timestamp for the screen. Refreshed on pull-to-refresh.
  DateTime _lastUpdated = DateTime.now();

  Future<void> _refresh() async {
    // TODO: Wire to backend finance endpoint when available.
    setState(() => _lastUpdated = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
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
            _LastUpdatedRow(lastUpdated: _lastUpdated),
            const SizedBox(height: 24),
            // Metric cards
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount =
                    constraints.maxWidth > 900 ? 3 : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth - (crossCount - 1) * 16) /
                          crossCount,
                      child: const _FinanceMetricCard(
                        icon: Icons.payments_rounded,
                        label: 'GMV (GROSS MERCHANDISE VALUE)',
                        value: '₹4,82,650',
                        subtitle: 'Sum of all completed payments',
                        color: AdminColors.accent,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - (crossCount - 1) * 16) /
                          crossCount,
                      child: const _FinanceMetricCard(
                        icon: Icons.savings_rounded,
                        label: 'COMMISSION REVENUE',
                        value: '₹0',
                        subtitle: '0% — drivers keep 100%',
                        color: AdminColors.info,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - (crossCount - 1) * 16) /
                          crossCount,
                      child: const _FinanceMetricCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'DRIVER PAYOUTS DUE',
                        value: '₹1,24,300',
                        subtitle: 'Pending settlements',
                        color: AdminColors.warning,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // Razorpay settlement log
            const _SettlementLogSection(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Last updated row
// ---------------------------------------------------------------------------

class _LastUpdatedRow extends StatelessWidget {
  const _LastUpdatedRow({required this.lastUpdated});
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 16, color: AdminColors.textMuted),
        const SizedBox(width: 6),
        Text(
          'Last updated: ${_formatTimestamp(lastUpdated)}',
          style: const TextStyle(fontSize: 13, color: AdminColors.textMuted),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}

// ---------------------------------------------------------------------------
// Finance metric card
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
    return Material(
      color: AdminColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
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
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Razorpay settlement log table
// ---------------------------------------------------------------------------

class _SettlementLogSection extends StatelessWidget {
  const _SettlementLogSection();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace mock settlement entries with real data from the
    // backend Razorpay settlement endpoint when available.
    final entries = _mockSettlements;

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
            // Table — horizontally scrollable on narrow screens.
            Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 600),
                  child: _SettlementTable(entries: entries),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementTable extends StatelessWidget {
  const _SettlementTable({required this.entries});
  final List<_SettlementEntry> entries;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AdminColors.textMuted,
      letterSpacing: 0.4,
    );
    final cellStyle = const TextStyle(
      fontSize: 13,
      color: AdminColors.textPrimary,
    );

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(140),
        1: FixedColumnWidth(120),
        2: FixedColumnWidth(120),
        3: FixedColumnWidth(180),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: AdminColors.border),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AdminColors.surfaceHover.withValues(alpha: 0.4),
          ),
          children: [
            _header('DATE', headerStyle),
            _header('AMOUNT', headerStyle),
            _header('STATUS', headerStyle),
            _header('REFERENCE ID', headerStyle),
          ],
        ),
        ...entries.map((e) => TableRow(
              children: [
                _cell(_formatDate(e.date), cellStyle),
                _cell(e.amount, cellStyle),
                _cell(e.status, cellStyle, statusColor: e.statusColor),
                _cell(e.referenceId, cellStyle),
              ],
            )),
      ],
    );
  }

  Widget _header(String text, TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text, style: style),
      );

  Widget _cell(String text, TextStyle style, {Color? statusColor}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: statusColor != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  text,
                  style: style.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              )
            : Text(text, style: style),
      );

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Mock data + models
// ---------------------------------------------------------------------------

class _SettlementEntry {
  const _SettlementEntry({
    required this.date,
    required this.amount,
    required this.status,
    required this.referenceId,
    required this.statusColor,
  });

  final DateTime date;
  final String amount;
  final String status;
  final String referenceId;
  final Color statusColor;
}

// TODO: Wire to backend Razorpay settlement endpoint. These are placeholder
// entries to demonstrate the table layout.
final _mockSettlements = <_SettlementEntry>[
  _SettlementEntry(
    date: DateTime(2025, 1, 15),
    amount: '₹86,200',
    status: 'Settled',
    referenceId: 'rzp_setl_8J2K9PQ',
    statusColor: AdminColors.success,
  ),
  _SettlementEntry(
    date: DateTime(2025, 1, 14),
    amount: '₹74,500',
    status: 'Settled',
    referenceId: 'rzp_setl_7H1G8MNO',
    statusColor: AdminColors.success,
  ),
  _SettlementEntry(
    date: DateTime(2025, 1, 13),
    amount: '₹92,300',
    status: 'Processing',
    referenceId: 'rzp_setl_6F0E7LMN',
    statusColor: AdminColors.warning,
  ),
  _SettlementEntry(
    date: DateTime(2025, 1, 12),
    amount: '₹68,900',
    status: 'Settled',
    referenceId: 'rzp_setl_5D9C6KLM',
    statusColor: AdminColors.success,
  ),
  _SettlementEntry(
    date: DateTime(2025, 1, 11),
    amount: '₹54,750',
    status: 'Failed',
    referenceId: 'rzp_setl_4B8B5JKL',
    statusColor: AdminColors.danger,
  ),
];

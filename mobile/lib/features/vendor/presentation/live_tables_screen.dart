import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/vendor_api.dart';

/// Partner app "Live Tables" tab — shows all checked-in bookings with
/// their prepaid cover charge credit. Waitstaff can see exactly how much
/// cover charge credit each table has available to spend on food and
/// drinks, and track it against the final bill at the end of the night.
///
/// The screen auto-refreshes every 15 seconds so newly scanned entries
/// appear without manual pull-to-refresh.
class LiveTablesScreen extends ConsumerStatefulWidget {
  const LiveTablesScreen({super.key});

  @override
  ConsumerState<LiveTablesScreen> createState() => _LiveTablesScreenState();
}

class _LiveTablesScreenState extends ConsumerState<LiveTablesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController;
  Timer? _refreshTimer;
  List<LiveTableEntry> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    _loadTables();
    // Auto-refresh every 15 seconds so newly scanned entries appear.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _loadTables();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTables() async {
    try {
      final tables = await ref.read(vendorApiProvider).getLiveTables();
      if (mounted) {
        setState(() {
          _tables = tables;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tables = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Tables'),
        actions: [
          // Auto-refresh indicator
          RotationTransition(
            turns: _refreshController,
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.sync, size: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppHaptics.light();
          await _loadTables();
        },
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(context)
                : _tables.isEmpty
                    ? _buildEmpty(context)
                    : _buildTableList(context),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(
          child: Icon(Icons.cloud_off, size: 64, color: AppTheme.danger),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Could not load live tables',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadTables();
            },
            child: Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.table_restaurant, size: 44, color: AppTheme.emerald),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'No active tables yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Scan a customer\'s QR ticket at the door\nto add them to Live Tables.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableList(BuildContext context) {
    // Summary header
    final totalGuests = _tables.fold<int>(0, (sum, t) => sum + t.guestCount);
    final totalCredit = _tables.fold<double>(0, (sum, t) => sum + t.creditAvailable);
    final totalCover = _tables.fold<double>(0, (sum, t) => sum + t.coverChargeAmount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _SummaryStat(
                icon: Icons.table_restaurant,
                label: 'Tables',
                value: '${_tables.length}',
              ),
              _SummaryStat(
                icon: Icons.people,
                label: 'Guests',
                value: '$totalGuests',
              ),
              _SummaryStat(
                icon: Icons.payments,
                label: 'Cover',
                value: '₹${totalCover.toStringAsFixed(0)}',
              ),
              _SummaryStat(
                icon: Icons.account_balance_wallet,
                label: 'Credit',
                value: '₹${totalCredit.toStringAsFixed(0)}',
                highlight: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Table cards
        ..._tables.map((table) => _LiveTableCard(table: table)),

        // VIP Escrow reserved table (demo feature)
        const SizedBox(height: 16),
        _EscrowReservedCard(),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: highlight ? AppTheme.emerald : null,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTableCard extends StatelessWidget {
  const _LiveTableCard({required this.table});

  final LiveTableEntry table;

  @override
  Widget build(BuildContext context) {
    final checkedInTime = '${table.checkedInAt.hour.toString().padLeft(2, '0')}:'
        '${table.checkedInAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Guest name + checked-in time
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: AppTheme.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.guestName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Checked in at $checkedInTime',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Guest count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${table.guestCount} guests',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Credit ledger
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CreditColumn(
                      label: 'Cover Charge',
                      value: '₹${table.coverChargeAmount.toStringAsFixed(0)}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _CreditColumn(
                      label: 'Credit Used',
                      value: '₹${table.creditUsed.toStringAsFixed(0)}',
                      color: AppTheme.danger,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _CreditColumn(
                      label: 'Available',
                      value: '₹${table.creditAvailable.toStringAsFixed(0)}',
                      color: AppTheme.emerald,
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditColumn extends StatelessWidget {
  const _CreditColumn({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows a VIP table held with an escrow auth-hold. If the guest doesn't
/// show up by the expiry time, the escrow is captured and the table is
/// released back into the app. This is a demo UI mockup.
class _EscrowReservedCard extends StatelessWidget {
  const _EscrowReservedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.lock_clock, color: AppTheme.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'VIP Couch 3',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'RESERVED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u20B95,000 Escrow Held \u2022 Expires 11:00 PM',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Auto-releases to pool if no-show',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

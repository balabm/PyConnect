import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Shows active disputes/chargebacks for the vendor's orders and allows
/// the partner to accept or reject a claim.
///
/// Each dispute card displays the order type, the disputed amount in red,
/// a status badge (Open / Won / Lost), an optional evidence summary and
/// resolution note, and the date the dispute was created. Tapping a card
/// expands it to reveal full details and, for Open disputes, the
/// `[ Accept Claim ]` and `[ Reject Claim ]` action buttons.
class VendorDisputesScreen extends ConsumerStatefulWidget {
  const VendorDisputesScreen({super.key});

  @override
  ConsumerState<VendorDisputesScreen> createState() =>
      _VendorDisputesScreenState();
}

class _VendorDisputesScreenState extends ConsumerState<VendorDisputesScreen> {
  List<Map<String, dynamic>> _disputes = [];
  bool _isLoading = true;
  String? _error;
  String? _expandedId;
  final Set<String> _actioningIds = {};

  @override
  void initState() {
    super.initState();
    // Load disputes on init so the screen is ready when first painted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDisputes());
  }

  Future<void> _loadDisputes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final disputes = await api.getDisputes();
      if (!mounted) return;
      setState(() {
        _disputes = disputes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptDispute(Map<String, dynamic> dispute) async {
    final id = (dispute['id'] ?? '').toString();
    if (id.isEmpty) return;
    final confirmed = await _confirmAction(
      title: 'Accept Claim?',
      message:
          'You will refund the customer ₹${_formatCurrency(_amountOf(dispute))} '
          'and close this dispute as lost. This cannot be undone.',
      confirmLabel: 'Accept Claim',
      isDestructive: true,
    );
    if (confirmed != true) return;

    AppHaptics.light();
    setState(() => _actioningIds.add(id));
    try {
      await ref.read(vendorDashboardApiProvider).acceptDispute(id);
      AppHaptics.success();
      if (!mounted) return;
      _toast('Claim accepted — refund processed');
      await _loadDisputes();
    } catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      _toast('Failed to accept claim: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actioningIds.remove(id));
    }
  }

  Future<void> _rejectDispute(Map<String, dynamic> dispute) async {
    final id = (dispute['id'] ?? '').toString();
    if (id.isEmpty) return;
    final confirmed = await _confirmAction(
      title: 'Reject Claim?',
      message:
          'You will contest this chargeback with the payment processor. '
          'Make sure you have evidence ready to submit.',
      confirmLabel: 'Reject Claim',
      isDestructive: false,
    );
    if (confirmed != true) return;

    AppHaptics.light();
    setState(() => _actioningIds.add(id));
    try {
      await ref.read(vendorDashboardApiProvider).rejectDispute(id);
      AppHaptics.success();
      if (!mounted) return;
      _toast('Claim rejected — contesting with processor');
      await _loadDisputes();
    } catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      _toast('Failed to reject claim: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actioningIds.remove(id));
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    AppHaptics.light();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
              backgroundColor:
                  isDestructive ? AppTheme.danger : AppTheme.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              AppHaptics.light();
              Navigator.of(ctx).pop(true);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? AppTheme.danger : AppTheme.emeraldDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Disputes'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () {
              AppHaptics.light();
              _loadDisputes();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.emerald),
      );
    }
    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadDisputes,
      );
    }
    if (_disputes.isEmpty) {
      return EmptyState(
        icon: Icons.gavel_outlined,
        title: 'No disputes',
        subtitle: 'Chargebacks and disputes on your orders will appear here.',
      );
    }
    return RefreshIndicator(
      color: AppTheme.emerald,
      onRefresh: _loadDisputes,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        itemCount: _disputes.length,
        itemBuilder: (_, i) {
          final dispute = _disputes[i];
          return _DisputeCard(
            dispute: dispute,
            expanded: _expandedId == (dispute['id'] ?? '').toString(),
            isActioning:
                _actioningIds.contains((dispute['id'] ?? '').toString()),
            onTap: () {
              AppHaptics.light();
              final id = (dispute['id'] ?? '').toString();
              setState(() {
                _expandedId = _expandedId == id ? null : id;
              });
            },
            onAccept: () => _acceptDispute(dispute),
            onReject: () => _rejectDispute(dispute),
          );
        },
      ),
    );
  }
}

/// A single dispute card. Tapping toggles an expanded view with full
/// details and action buttons for Open disputes.
class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.expanded,
    required this.isActioning,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });

  final Map<String, dynamic> dispute;
  final bool expanded;
  final bool isActioning;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  String get _status => (dispute['status'] ?? 'Open').toString();
  bool get _isOpen =>
      _status.toLowerCase() == 'open' || _status.toLowerCase() == 'pending';

  @override
  Widget build(BuildContext context) {
    final orderType = (dispute['orderType'] ?? 'Order').toString();
    final amount = _amountOf(dispute);
    final evidence = (dispute['evidenceSummary'] ?? '').toString();
    final resolution = (dispute['resolutionNote'] ?? '').toString();
    final createdAt = (dispute['createdAt'] ?? '').toString();
    final resolvedAt = (dispute['resolvedAt'] ?? '').toString();
    final orderId = (dispute['orderId'] ?? '').toString();
    final paymentId = (dispute['paymentId'] ?? '').toString();

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: order type badge + status badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                _OrderTypeBadge(orderType: orderType),
                const Spacer(),
                _StatusBadge(status: _status),
              ],
            ),
          ),
          // ── Amount + date row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20B9${_formatCurrency(amount)}',
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'chargeback',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // ── Evidence summary (collapsed preview) ──
          if (evidence.isNotEmpty && !expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                evidence,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          // ── Resolution note (collapsed preview) ──
          if (resolution.isNotEmpty && !expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 13,
                    color: AppTheme.emerald,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      resolution,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── Expand chevron ──
          if (evidence.isEmpty && resolution.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expanded ? 'Hide details' : 'View details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // ── Expanded details ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _ExpandedDetails(
              orderId: orderId,
              paymentId: paymentId,
              evidence: evidence,
              resolution: resolution,
              resolvedAt: resolvedAt,
              isOpen: _isOpen,
              isActioning: isActioning,
              onAccept: onAccept,
              onReject: onReject,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanded section with full details and action buttons.
class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({
    required this.orderId,
    required this.paymentId,
    required this.evidence,
    required this.resolution,
    required this.resolvedAt,
    required this.isOpen,
    required this.isActioning,
    required this.onAccept,
    required this.onReject,
  });

  final String orderId;
  final String paymentId;
  final String evidence;
  final String resolution;
  final String resolvedAt;
  final bool isOpen;
  final bool isActioning;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          if (orderId.isNotEmpty) _DetailRow(label: 'Order ID', value: orderId),
          if (paymentId.isNotEmpty)
            _DetailRow(label: 'Payment ID', value: paymentId),
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Evidence Summary',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              evidence,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          if (resolution.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.task_alt, size: 15, color: AppTheme.emerald),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resolution Note',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resolution,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (resolvedAt.isNotEmpty)
            _DetailRow(label: 'Resolved', value: _formatDate(resolvedAt)),
          if (isOpen) ...[
            const SizedBox(height: AppSpacing.lg),
            if (isActioning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Accept Claim'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: onReject,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reject Claim'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Order type badge (e.g. "Food Order", "Equipment Rental").
class _OrderTypeBadge extends StatelessWidget {
  const _OrderTypeBadge({required this.orderType});
  final String orderType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _orderTypeMeta(orderType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            orderType,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _orderTypeMeta(String type) {
    final t = type.toLowerCase();
    if (t.contains('food') || t.contains('restaurant') || t.contains('pizzeria') || t.contains('cafe')) {
      return (Icons.restaurant, AppTheme.emerald);
    }
    if (t.contains('equipment') || t.contains('rental') || t.contains('scooter')) {
      return (Icons.pedal_bike, AppTheme.sky);
    }
    if (t.contains('transit') || t.contains('taxi') || t.contains('ride')) {
      return (Icons.local_taxi, AppTheme.sky);
    }
    if (t.contains('luggage') || t.contains('cloak')) {
      return (Icons.luggage, AppTheme.gold);
    }
    if (t.contains('nightlife') || t.contains('pub') || t.contains('club')) {
      return (Icons.nightlife, AppTheme.emerald);
    }
    return (Icons.receipt_long, AppTheme.slate);
  }
}

/// Status badge: Open (amber), Won (green), Lost (red).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final (color, label) = switch (lower) {
      'open' || 'pending' => (AppTheme.warning, 'Open'),
      'won' || 'accepted' || 'resolved' => (AppTheme.emerald, 'Won'),
      'lost' || 'rejected' || 'closed' => (AppTheme.danger, 'Lost'),
      _ => (AppTheme.slate, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Helpers ──

double _amountOf(Map<String, dynamic> dispute) {
  final raw = dispute['chargebackAmount'] ?? dispute['amount'] ?? 0;
  return (raw is num) ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
}

/// Formats a numeric amount with thousands separators,
/// e.g. 1234.5 → "1,234" (no decimals for clean display).
String _formatCurrency(double amount) {
  final rounded = amount.round();
  final isNegative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return isNegative ? '-$buffer' : buffer.toString();
}

/// Formats an ISO-8601 date string as "dd MMM yyyy, hh:mm a".
String _formatDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} $amPm';
  } catch (_) {
    return iso;
  }
}

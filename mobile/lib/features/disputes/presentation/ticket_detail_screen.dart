import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../support/data/support_api.dart';

/// Admin dispute-ticket detail view with an issue-refund workflow.
///
/// Shows the customer, issue category, order reference and description.
/// The `[ Issue Refund ]` button opens an [AlertDialog] with `Full Refund`
/// and `Partial Amount: ₹__` options; confirming calls
/// `POST /api/admin/tickets/{id}/refund`.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticket,
    this.onRefunded,
  });

  final DisputeTicketDetail ticket;
  final VoidCallback? onRefunded;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  bool _refunding = false;

  Future<void> _issueRefund() async {
    final result = await showDialog<_RefundOption>(
      context: context,
      builder: (ctx) => const _RefundDialog(),
    );

    if (result == null) return;

    setState(() => _refunding = true);
    try {
      final res = await ref.read(adminApiProvider).refundTicket(
            widget.ticket.id,
            fullRefund: result.fullRefund,
            amount: result.amount,
          );

      if (!mounted) return;

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message?.isNotEmpty == true
                  ? res.message!
                  : 'Refund of ₹${res.refundAmount.toStringAsFixed(2)} issued successfully.',
            ),
            backgroundColor: AdminColors.success,
          ),
        );

        widget.onRefunded?.call();
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund was not successful.'),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund failed: $e'),
          backgroundColor: AdminColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _refunding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final orderInfo = ticket.orderId != null
        ? '${ticket.orderType ?? 'Order'} · ${ticket.orderId}'
        : 'No linked order';

    return Scaffold(
      appBar: AppBar(title: const Text('Dispute Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusChip(status: ticket.status),
            const SizedBox(height: 16),
            _SectionTitle('Customer'),
            _Field(label: 'Customer ID', value: ticket.id),
            _Field(label: 'Category', value: ticket.category),
            _Field(label: 'Subject', value: ticket.subject),
            const SizedBox(height: 16),
            _SectionTitle('Order Info'),
            _Field(label: 'Order', value: orderInfo),
            _Field(
              label: 'Created',
              value: _formatDate(ticket.createdAt),
            ),
            if (ticket.resolvedAt != null)
              _Field(
                label: 'Resolved',
                value: _formatDate(ticket.resolvedAt!),
              ),
            const SizedBox(height: 16),
            _SectionTitle('Issue'),
            Text(
              ticket.description,
              style: const TextStyle(
                color: AdminColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (ticket.resolutionNote != null &&
                ticket.resolutionNote!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle('Resolution'),
              Text(
                ticket.resolutionNote!,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _refunding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.currency_rupee_rounded, size: 20),
                label: Text(_refunding ? 'PROCESSING…' : 'ISSUE REFUND'),
                onPressed: _refunding || ticket.status == 'Resolved'
                    ? null
                    : _issueRefund,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _RefundOption {
  const _RefundOption({required this.fullRefund, this.amount});
  final bool fullRefund;
  final double? amount;
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog();

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  bool _fullRefund = true;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Issue Refund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how to settle this dispute.',
            style: TextStyle(color: AdminColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          RadioListTile<bool>(
            title: const Text('Full Refund'),
            value: true,
            groupValue: _fullRefund,
            onChanged: (v) => setState(() => _fullRefund = v!),
            activeColor: AdminColors.accent,
          ),
          RadioListTile<bool>(
            title: const Text('Partial Amount'),
            value: false,
            groupValue: _fullRefund,
            onChanged: (v) => setState(() => _fullRefund = v!),
            activeColor: AdminColors.accent,
          ),
          if (!_fullRefund)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Partial Amount',
                  hintText: 'e.g. 125.50',
                ),
                autofocus: true,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: AdminColors.warning,
              foregroundColor: Colors.white),
          onPressed: () {
            if (_fullRefund) {
              Navigator.pop(context, const _RefundOption(fullRefund: true));
              return;
            }

            final value = double.tryParse(_amountController.text.trim());
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a valid partial amount'),
                  backgroundColor: AdminColors.danger,
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              _RefundOption(fullRefund: false, amount: value),
            );
          },
          child: const Text('Confirm Refund'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'open':
        return AdminColors.info;
      case 'resolved':
      case 'autoresolved':
        return AdminColors.success;
      case 'underreview':
      case 'escalated':
        return AdminColors.danger;
      default:
        return AdminColors.textMuted;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AdminColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  color: AdminColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: AdminColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Partial refund screen for food vendors.
///
/// The partner selects an order and an item to remove (out of stock).
/// The backend removes the item, calculates the refund amount, and
/// triggers a Razorpay partial refund if the order was paid online.
class PartialRefundScreen extends ConsumerStatefulWidget {
  const PartialRefundScreen({super.key, this.orderId});

  final String? orderId;

  @override
  ConsumerState<PartialRefundScreen> createState() => _PartialRefundScreenState();
}

class _PartialRefundScreenState extends ConsumerState<PartialRefundScreen> {
  final _orderIdController = TextEditingController();
  final _itemIdController = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null) _orderIdController.text = widget.orderId!;
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _itemIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_orderIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    if (_itemIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.partialRefund(
        _orderIdController.text.trim(),
        _itemIdController.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult(context);
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partial Refund')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use this when an item is out of stock after accepting the order. The customer will be automatically refunded for that item.',
                      style: TextStyle(color: AppTheme.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Order ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _orderIdController,
              decoration: const InputDecoration(
                hintText: 'Paste the order ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
            const SizedBox(height: 24),
            Text('Item ID to Remove', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _itemIdController,
              decoration: const InputDecoration(
                hintText: 'Paste the item ID that is out of stock',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.remove_circle_outline),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.warning),
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.money_off),
                label: Text(_submitting ? 'Processing...' : 'Remove Item & Refund'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final refundAmount = _result!['refundAmount'] ?? 0;
    final newTotal = _result!['newTotal'] ?? 0;
    final message = _result!['message'] ?? 'Item removed and refund processed.';

    return Scaffold(
      appBar: AppBar(title: const Text('Refund Processed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
              const SizedBox(height: 16),
              const Text('Refund Processed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 24),
              _ResultRow(label: 'Refund Amount', value: '₹$refundAmount', color: AppTheme.danger),
              _ResultRow(label: 'New Order Total', value: '₹$newTotal', color: AppTheme.emerald),
              const SizedBox(height: 32),
              FilledButton(onPressed: () => context.pop(), child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// A bottom sheet for COD exact-change reconciliation.
///
/// When a customer pays with a large note and the driver has no change,
/// the driver can input the collected amount. The app calculates the
/// difference, debits the driver's internal ledger, and credits the
/// consumer's PY Wallet instantly. Both parties walk away happy.
class CodCollectionSheet {
  CodCollectionSheet._();

  /// Shows the COD collection sheet. Returns true if the reconciliation
  /// was successful.
  static Future<bool?> show(
    BuildContext context,
    WidgetRef ref, {
    required String rideId,
    required double orderTotal,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CodCollectionContent(
        rideId: rideId,
        orderTotal: orderTotal,
        ref: ref,
      ),
    );
  }
}

class _CodCollectionContent extends ConsumerStatefulWidget {
  const _CodCollectionContent({
    required this.rideId,
    required this.orderTotal,
    required this.ref,
  });

  final String rideId;
  final double orderTotal;
  final WidgetRef ref;

  @override
  ConsumerState<_CodCollectionContent> createState() => _CodCollectionContentState();
}

class _CodCollectionContentState extends ConsumerState<_CodCollectionContent> {
  final _collectedController = TextEditingController();
  bool _processing = false;
  double? _changeAmount;

  double get _collectedAmount =>
      double.tryParse(_collectedController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _collectedController.text = widget.orderTotal.toStringAsFixed(0);
    _collectedController.addListener(() {
      final change = _collectedAmount - widget.orderTotal;
      setState(() => _changeAmount = change > 0 ? change : 0);
    });
  }

  @override
  void dispose() {
    _collectedController.dispose();
    super.dispose();
  }

  Future<void> _reconcile() async {
    if (_collectedAmount < widget.orderTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collected amount cannot be less than the order total.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    AppHaptics.medium();
    setState(() => _processing = true);

    try {
      final api = widget.ref.read(ridesApiProvider);
      final result = await api.codReconcile(
        widget.rideId,
        _collectedAmount,
        widget.orderTotal,
      );

      final change = (result['changeAmount'] as num?)?.toDouble() ?? 0;
      final message = result['message'] as String? ?? 'Reconciliation complete.';

      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reconciliation failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = _changeAmount ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'COD Collection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order Total: \u20B9${widget.orderTotal.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _collectedController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Collected Amount (\u20B9)',
              prefixText: '\u20B9 ',
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.emerald, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (change > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.emerald),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change: \u20B9${change.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'This amount will be credited to the customer\'s PY Wallet instantly.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(),
                  onPressed: _processing ? null : _reconcile,
                  child: _processing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Change to PY Wallet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

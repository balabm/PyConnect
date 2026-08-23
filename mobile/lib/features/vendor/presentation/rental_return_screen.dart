import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// Rental return completion screen for ScooterRental vendors.
///
/// The partner enters late minutes and damage amount (if any), then
/// the backend calculates the penalty, determines the deposit refund,
/// and completes the rental return.
class RentalReturnScreen extends ConsumerStatefulWidget {
  const RentalReturnScreen({super.key, this.rentalId});

  final String? rentalId;

  @override
  ConsumerState<RentalReturnScreen> createState() => _RentalReturnScreenState();
}

class _RentalReturnScreenState extends ConsumerState<RentalReturnScreen> {
  final _rentalIdController = TextEditingController();
  final _damageController = TextEditingController(text: '0');
  int _lateMinutes = 0;
  bool _submitting = false;
  RentalReturnResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.rentalId != null) _rentalIdController.text = widget.rentalId!;
  }

  @override
  void dispose() {
    _rentalIdController.dispose();
    _damageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rentalIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    final damage = double.tryParse(_damageController.text) ?? 0;
    if (damage < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Damage amount cannot be negative'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final result = await api.completeRentalReturn(
        _rentalIdController.text.trim(),
        lateMinutes: _lateMinutes,
        damageAmount: damage,
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
      appBar: AppBar(title: const Text('Complete Rental Return')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter late minutes and damage amount (if any). The backend will calculate penalties and determine the deposit refund.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: _rentalIdController,
              decoration: const InputDecoration(
                labelText: 'Rental ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
            const SizedBox(height: 24),
            Text('Late Minutes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filled(
                  onPressed: _lateMinutes > 0 ? () => setState(() => _lateMinutes -= 15) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center(
                    child: Text('${_lateMinutes}m', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton.filled(
                  onPressed: () => setState(() => _lateMinutes += 15),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [0, 15, 30, 60, 120].map((m) => ChoiceChip(
                label: Text(m == 0 ? 'On time' : '${m}m'),
                selected: _lateMinutes == m,
                onSelected: (_) => setState(() => _lateMinutes = m),
              )).toList(),
            ),
            const SizedBox(height: 24),
            Text('Damage Amount (₹)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _damageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle),
                label: Text(_submitting ? 'Processing...' : 'Complete Return'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final r = _result!;
    return Scaffold(
      appBar: AppBar(title: const Text('Rental Return Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: AppTheme.emerald, size: 56),
            const SizedBox(height: 16),
            const Text('Return Completed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _SummaryRow(label: 'Security Deposit', value: '₹${r.securityDeposit.toStringAsFixed(2)}'),
            _SummaryRow(label: 'Penalty Deducted', value: '₹${r.penaltyDeducted.toStringAsFixed(2)}', color: r.penaltyDeducted > 0 ? AppTheme.danger : null),
            _SummaryRow(label: 'Deposit Refunded', value: '₹${r.depositRefunded.toStringAsFixed(2)}', color: AppTheme.emerald),
            const Divider(height: 32),
            _SummaryRow(label: 'Total Amount', value: '₹${r.totalAmount.toStringAsFixed(2)}', isBold: true),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.color});
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

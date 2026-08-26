import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../data/consumer_equipment_api.dart';

/// Equipment detail and booking screen.
/// Shows full equipment info and lets the consumer select dates, units,
/// and complete a Razorpay checkout for the rental.
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  const EquipmentDetailScreen({super.key, required this.item});

  final ConsumerEquipmentItemModel item;

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  int _units = 1;
  DateTime? _startDate;
  DateTime? _endDate;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _booking = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _rentalDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  double get _rentalTotal => _rentalDays * widget.item.dailyRentalPrice * _units;
  double get _depositTotal => widget.item.securityDepositAmount * _units;
  double get _grandTotal => _rentalTotal + _depositTotal;

  bool get _canBook =>
      _units > 0 &&
      _units <= widget.item.availableUnits &&
      _startDate != null &&
      _endDate != null &&
      _rentalDays > 0 &&
      !_booking;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: isStart ? 'Select rental start date' : 'Select rental end date',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Reset end if it's before start
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _bookRental() async {
    if (!_canBook) return;

    AppHaptics.light();
    setState(() => _booking = true);

    try {
      final api = ref.read(consumerEquipmentApiProvider);
      final result = await api.createRental(
        equipmentItemId: widget.item.id,
        unitsBooked: _units,
        rentalStart: _startDate!,
        rentalEnd: _endDate!,
        deliveryAddress: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // If there's a Razorpay order, launch checkout
      final razorpayOrderId = result.razorpayOrderId;
      if (razorpayOrderId != null && razorpayOrderId.isNotEmpty) {
        await _launchRazorpayAndConfirm(
          rentalId: result.rentalId,
          razorpayOrderId: razorpayOrderId,
          amount: result.totalAmount + result.securityDeposit,
        );
      } else {
        // Free rental (no payment required) — already confirmed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Rental booked successfully!'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _launchRazorpayAndConfirm({
    required String rentalId,
    required String razorpayOrderId,
    required double amount,
  }) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    paymentService.init();

    try {
      final paymentResult = await paymentService
          .startPayment(
            orderId: razorpayOrderId,
            amount: (amount * 100).round(), // paise
            phone: authSession?.phone ?? '',
            userName: authSession?.name,
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => PaymentError(
              code: -1,
              message: 'Payment timed out. Please try again.',
            ),
          );

      if (!mounted) return;

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          try {
            await ref.read(consumerEquipmentApiProvider).confirmRental(
                  rentalId: rentalId,
                  razorpayOrderId: orderId,
                  razorpayPaymentId: paymentId,
                  signature: signature ?? '',
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Rental confirmed! The vendor will contact you.'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
              context.pop();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment succeeded but confirmation failed: $e'),
                  backgroundColor: AppTheme.danger,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        case PaymentError(:final message):
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $message'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Payment via wallet. Verifying...'),
                backgroundColor: AppTheme.info,
              ),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, style: const TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.emerald.withValues(alpha: 0.2), AppTheme.emerald.withValues(alpha: 0.05)],
                ),
              ),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      ),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(height: 20),
            // Name and category
            Text(
              item.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.vendorName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Description
            if (item.description != null && item.description!.isNotEmpty) ...[
              Text(
                item.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Pricing
            _buildPricingCard(),
            const SizedBox(height: 20),
            // Units selector
            Text('Units', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _units > 1 ? () => setState(() => _units--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.emerald,
                ),
                Text('$_units', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _units < item.availableUnits
                      ? () => setState(() => _units++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.emerald,
                ),
                const SizedBox(width: 12),
                Text(
                  '${item.availableUnits} available',
                  style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.7)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Date selection
            Text('Rental Period', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateTile(
                    label: 'Start',
                    date: _startDate,
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTile(
                    label: 'End',
                    date: _endDate,
                    onTap: () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Delivery address
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address (optional)',
                hintText: 'Where should the equipment be delivered?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special instructions for the vendor',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            // Cost summary
            if (_rentalDays > 0) _buildCostSummary(),
            const SizedBox(height: 20),
            // Book button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canBook ? _bookRental : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.emerald,
                ),
                child: _booking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _rentalDays > 0
                            ? 'Book for \u20B9${_grandTotal.toStringAsFixed(0)}'
                            : 'Select dates to book',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(Icons.speaker, size: 64, color: AppTheme.emerald.withValues(alpha: 0.4)),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 0,
      color: AppTheme.emerald.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PriceInfo(
              label: 'Daily Rate',
              value: '\u20B9${widget.item.dailyRentalPrice.toStringAsFixed(0)}',
            ),
            _PriceInfo(
              label: 'Security Deposit',
              value: '\u20B9${widget.item.securityDepositAmount.toStringAsFixed(0)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummary() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _CostRow(
              label: '$_units unit(s) \u00D7 $_rentalDays day(s)',
              value: '\u20B9${_rentalTotal.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 6),
            _CostRow(
              label: 'Security deposit',
              value: '\u20B9${_depositTotal.toStringAsFixed(0)}',
              subtitle: 'Refundable on return',
            ),
            const Divider(height: 20),
            _CostRow(
              label: 'Total',
              value: '\u20B9${_grandTotal.toStringAsFixed(0)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceInfo extends StatelessWidget {
  const _PriceInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : 'Select date',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: date != null ? null : AppTheme.slate.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.value, this.subtitle, this.isBold = false});
  final String label;
  final String value;
  final String? subtitle;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 16 : 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(fontSize: 11, color: AppTheme.slate.withValues(alpha: 0.6)),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? AppTheme.emerald : null,
          ),
        ),
      ],
    );
  }
}

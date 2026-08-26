import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../data/party_services_api.dart';

/// Consumer screen for viewing a party service detail and booking it.
class PartyServiceDetailScreen extends ConsumerStatefulWidget {
  const PartyServiceDetailScreen({super.key, required this.serviceId, this.service});

  final String serviceId;
  final PartyServiceModel? service;

  @override
  ConsumerState<PartyServiceDetailScreen> createState() =>
      _PartyServiceDetailScreenState();
}

class _PartyServiceDetailScreenState
    extends ConsumerState<PartyServiceDetailScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  int _quantity = 1;
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _booking = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final basePrice = widget.service?.basePrice ?? 0;
    return basePrice * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    if (service == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Service not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(service.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                  ? Image.network(
                      service.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Placeholder(category: service.category),
                    )
                  : _Placeholder(category: service.category),
            ),
            const SizedBox(height: 16),
            // Title + category
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    service.category,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(service.vendorName, style: TextStyle(fontSize: 14, color: AppTheme.slate.withValues(alpha: 0.7))),
            if (service.serviceArea != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.slate.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(service.serviceArea!, style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.5))),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Description
            if (service.description != null) ...[
              Text(service.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
            ],
            // Pricing
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u20B9${service.basePrice.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                      Text(
                        service.pricingUnit,
                        style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  Text(
                    'Min: ${service.minimumBooking}',
                    style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Booking form
            const Text('Book This Service', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Event date
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Event Date: ${_formatDate(_selectedDate)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const Divider(),
            // Quantity
            ListTile(
              leading: const Icon(Icons.numbers),
              title: Text('Quantity: $_quantity ${service.pricingUnit}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > service.minimumBooking
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Address
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Event Address',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            // Notes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            // Total + book button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6))),
                    Text(
                      '\u20B9${_totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: _booking ? null : _bookService,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: _booking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Book & Pay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _bookService() async {
    final service = widget.service;
    if (service == null) return;

    AppHaptics.light();
    setState(() => _booking = true);

    try {
      // 1. Create booking
      final result = await ref.read(partyServicesApiProvider).createBooking(
            serviceId: service.id,
            eventDate: _selectedDate,
            quantity: _quantity,
            eventAddress: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

      // 2. Launch Razorpay checkout
      final paymentService = ref.read(razorpayPaymentProvider);
      final authSession = ref.read(authControllerProvider).valueOrNull;
      paymentService.init();

      final paymentResult = await paymentService
          .startPayment(
            orderId: '',
            amount: (result.totalAmount * 100).round(),
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
        case PaymentSuccess(:final orderId, :final paymentId):
          // 3. Confirm booking with payment details
          await ref.read(partyServicesApiProvider).confirmBooking(
                bookingId: result.bookingId,
                razorpayOrderId: orderId,
                razorpayPaymentId: paymentId,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Booking confirmed! Total: \u20B9${result.totalAmount.toStringAsFixed(0)}'),
                backgroundColor: AppTheme.emerald,
              ),
            );
            Navigator.of(context).pop();
          }
        case PaymentError(:final message):
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment failed: $message'), backgroundColor: AppTheme.danger),
            );
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment via wallet. Please verify.'), backgroundColor: AppTheme.info),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.category});
  final String category;

  IconData get _icon {
    switch (category) {
      case 'DJ': return Icons.music_note;
      case 'Bartender': return Icons.local_bar;
      case 'Catering': return Icons.restaurant;
      case 'SoundSystem': return Icons.speaker;
      case 'Lighting': return Icons.lightbulb;
      case 'Photography': return Icons.camera_alt;
      case 'Decoration': return Icons.deck;
      case 'Host': return Icons.mic;
      case 'Security': return Icons.security;
      default: return Icons.celebration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      color: AppTheme.emerald.withValues(alpha: 0.08),
      child: Icon(_icon, size: 56, color: AppTheme.emerald.withValues(alpha: 0.3)),
    );
  }
}

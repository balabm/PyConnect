import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/quick_auth_sheet.dart';
import '../../venues/application/venue_controller.dart';
import '../../venues/data/venue_api.dart';
import '../data/booking_api.dart';
import '../../../core/widgets/skeleton_loaders.dart';

/// Cover-charge plus table reservation flow for a venue.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.venueId, this.initialVenue});

  final String venueId;
  final Venue? initialVenue;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _seats = 2;
  DateTime _scheduledFor = DateTime.now().add(const Duration(hours: 2));
  bool _submitting = false;
  String? _error;
  Venue? _resolvedVenue;
  BookingResult? _bookingResult;

  /// Razorpay payment guard state.
  bool _paymentInProgress = false;
  Timer? _paymentGuardTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize Razorpay SDK early so it's ready when the user checks out.
    ref.read(razorpayPaymentProvider).init();
    _resolveVenue();
  }

  @override
  void didUpdateWidget(covariant BookingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venueId != widget.venueId ||
        oldWidget.initialVenue != widget.initialVenue) {
      _resolveVenue();
    }
  }

  void _resolveVenue() {
    if (widget.initialVenue != null) {
      _resolvedVenue = widget.initialVenue;
      return;
    }
    final venues = ref.read(venueListProvider).valueOrNull ?? const <Venue>[];
    _resolvedVenue = venues.cast<Venue?>().firstWhere(
      (v) => v != null && v.id == widget.venueId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authTokenProvider)?.isNotEmpty ?? false;

    if (_resolvedVenue == null) {
      final isLoading = ref.watch(venueListProvider).isLoading;
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: Center(
          child: isLoading
              ? const SkeletonList(type: SkeletonType.booking, count: 1)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    const Text('Venue not found'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        AppHaptics.light();
                        context.pop();
                      },
                      child: const Text('Go back'),
                    ),
                  ],
                ),
        ),
      );
    }

    final venue = _resolvedVenue!;

    if (_bookingResult != null) {
      return _BookingSuccessScreen(
        venue: venue,
        result: _bookingResult!,
        seats: _seats,
        scheduledFor: _scheduledFor,
      );
    }

    final cover = _coverCharge(venue.category);
    final total = cover * _seats;
    final occupancyPct = venue.occupancy.clamp(0, 100).toInt();
    final isAtCapacity = occupancyPct >= 100;
    final availableCapacity = venue.maxCapacity != null
        ? (venue.maxCapacity! - (venue.maxCapacity! * occupancyPct ~/ 100))
        : null;
    final exceedsCapacity = availableCapacity != null && _seats > availableCapacity;

    return Scaffold(
      appBar: AppBar(title: Text('Book · ${venue.name}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Proactive capacity banner
          if (isAtCapacity)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.do_not_disturb, color: AppTheme.danger, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This venue is at full capacity. Booking is currently unavailable.',
                      style: TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (exceedsCapacity)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only $availableCapacity ${availableCapacity == 1 ? 'seat' : 'seats'} available. Reduce guest count.',
                      style: TextStyle(color: AppTheme.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          _Section(
            title: 'How many?',
            child: _SeatStepper(
              value: _seats,
              onChange: (v) => setState(() => _seats = v),
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'When?',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month, color: AppTheme.emerald),
              title: Text(
                '${_scheduledFor.day}/${_scheduledFor.month}/${_scheduledFor.year} '
                '· ${_scheduledFor.hour.toString().padLeft(2, '0')}:'
                '${_scheduledFor.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppHaptics.selection();
                _pickDateTime(context);
              },
            ),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Row(
                    label: 'Cover charge (₹$cover)',
                    value: '$cover × $_seats',
                  ),
                  const SizedBox(height: 8),
                  _Row(label: 'Total', value: '₹$total', emphasized: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: !_submitting && !isAtCapacity && !exceedsCapacity
                ? () async {
                    AppHaptics.light();
                    if (!isAuthenticated) {
                      final authenticated = await QuickAuthSheet.show(
                        context,
                        ref,
                        title: 'Sign in to book',
                      );
                      if (authenticated != true || !mounted) return;
                    }
                    _submit();
                  }
                : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isAtCapacity ? Icons.do_not_disturb : Icons.check_circle_outline),
            label: Text(
              isAtCapacity
                  ? 'Sold Out'
                  : exceedsCapacity
                      ? 'Reduce guest count'
                      : isAuthenticated
                          ? 'Confirm ₹$total'
                          : 'Sign in to book',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledFor),
    );
    if (time == null) return;

    setState(() {
      _scheduledFor = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final booking = await BookingApi(ref.read(apiClientProvider)).create(
        venueId: widget.venueId,
        seats: _seats,
        scheduledFor: _scheduledFor,
        notes: 'Vibe-check entry via PY Connect',
      );
      if (!mounted) return;

      final cover = _coverCharge(_resolvedVenue?.category ?? '');
      final total = cover * _seats;

      await _initiateRazorpayPayment(
        serviceBookingId: booking.bookingId,
        amount: total.toDouble(),
        booking: booking,
      );
    } catch (e) {
      setState(() {
        _error = 'Booking failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _initiateRazorpayPayment({
    required String serviceBookingId,
    required double amount,
    required BookingResult booking,
  }) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    setState(() => _paymentInProgress = true);
    _paymentGuardTimer?.cancel();
    _paymentGuardTimer = Timer(const Duration(minutes: 5), () {
      if (!_paymentInProgress) return;
      if (mounted) {
        setState(() => _paymentInProgress = false);
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Overlay may already be dismissed.
        }
        _showPaymentCancelledSnackBar();
      }
    });

    try {
      final order = await paymentService.createOrder(
        amount: amount,
        serviceBookingId: serviceBookingId,
      );

      if (!mounted) return;

      _showProcessingOverlay();

      final paymentResult = await paymentService
          .startPayment(
            orderId: order.providerOrderId,
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
      _paymentGuardTimer?.cancel();
      setState(() => _paymentInProgress = false);
      Navigator.of(context, rootNavigator: true).pop();

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          // Verify payment signature on backend before confirming.
          final verified = await paymentService.verifyPayment(
            paymentId: order.paymentId,
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
          );
          if (!mounted) return;
          if (!verified) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment verification failed. Please contact support.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _error = 'Payment verification failed');
            return;
          }
          // Only confirm the booking once the backend has verified payment.
          setState(() => _bookingResult = booking);
        case PaymentError(:final code, :final message):
          if (mounted) {
            _showPaymentCancelledSnackBar();
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('External wallet selected. Please complete payment.')),
            );
          }
      }
    } catch (e) {
      _paymentGuardTimer?.cancel();
      setState(() => _paymentInProgress = false);
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Overlay may already be dismissed.
        }
        _showPaymentCancelledSnackBar();
        setState(() => _error = 'Payment initiation failed: $e');
      }
    }
  }

  void _showProcessingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Processing payment...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait for confirmation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentCancelledSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment cancelled. Your booking is saved.'),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

int _coverCharge(String category) => switch (category) {
      'Club' => 500,
      'Pub' => 200,
      'Bar' => 150,
      _ => 100,
    };

/// Success screen shown after a booking is confirmed.
/// Displays a pass token with booking ID, amount, and venue details.
class _BookingSuccessScreen extends StatelessWidget {
  const _BookingSuccessScreen({
    required this.venue,
    required this.result,
    required this.seats,
    required this.scheduledFor,
  });

  final Venue venue;
  final BookingResult result;
  final int seats;
  final DateTime scheduledFor;

  @override
  Widget build(BuildContext context) {
    final passToken = result.passToken.isNotEmpty
        ? result.passToken
        : result.bookingId.split('-').last.toUpperCase().substring(0, 8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppHaptics.light();
            context.go('/venues/${venue.id}');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 40, color: AppTheme.emerald),
          ),
          const SizedBox(height: 16),
          Text(
            'You\'re in!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Show this pass at ${venue.name} entry',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          // Pass token card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.nightGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Text(
                  'PASS TOKEN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  passToken,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    result.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Booking details
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'Venue', value: venue.name),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Guests', value: '$seats'),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Date & Time',
                    value: '${scheduledFor.day}/${scheduledFor.month}/${scheduledFor.year} '
                        '· ${scheduledFor.hour.toString().padLeft(2, '0')}:'
                        '${scheduledFor.minute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(
                    label: 'Amount Paid',
                    value: '\u20B9${result.amount.toStringAsFixed(0)}',
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              AppHaptics.light();
              context.go('/venues/${venue.id}');
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to venue'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              AppHaptics.light();
              context.go('/');
            },
            icon: const Icon(Icons.home),
            label: const Text('Go home'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        Text(
          value,
          style: emphasized
              ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _SeatStepper extends StatelessWidget {
  const _SeatStepper({required this.value, required this.onChange});

  final int value;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.remove,
          onTap: value > 1 ? () => onChange(value - 1) : null,
        ),
        const SizedBox(width: 16),
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(width: 16),
        _CircleButton(
          icon: Icons.add,
          onTap: value < 200 ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      onPressed: enabled
          ? () {
              AppHaptics.selection();
              onTap!();
            }
          : null,
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? AppTheme.emerald.withValues(alpha: 0.15)
            : Theme.of(context).disabledColor.withValues(alpha: 0.2),
        foregroundColor: enabled ? AppTheme.emerald : Theme.of(context).disabledColor,
      ),
      icon: Icon(icon),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          value,
          style: style?.copyWith(
            fontWeight: emphasized ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}
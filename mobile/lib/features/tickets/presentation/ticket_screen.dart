import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../bookings/data/booking_api.dart';

/// Consumer-facing ticket screen displaying a cryptographically signed QR
/// code with anti-screenshot protections:
///
/// 1. **Live digital clock overlay** — a running clock with seconds ticking
///    is rendered directly on top of the QR code. If a fraudster takes a
///    screenshot, the clock freezes. The bouncer can spot a static clock
///    before even scanning.
///
/// 2. **Pulsing background animation** — a subtle emerald pulse behind the
///    QR code proves the screen is a live app, not a static gallery image.
///
/// 3. **Cryptographically signed payload** — the QR data is an HMAC-SHA256
///    signed token combining BookingId + UserId + Amount + ScheduledFor.
///    A forged QR code without the correct signature will fail validation.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Timer? _clockTimer;
  DateTime _clockNow = DateTime.now();
  TicketDto? _ticket;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Tick the clock every second so the bouncer can see it's live.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clockNow = DateTime.now());
    });
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    try {
      final ticket = await ref.read(bookingApiProvider).getTicket(widget.bookingId);
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _loading = false;
        });
        AppHaptics.success();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Ticket'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(context)
              : _buildTicket(context),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(
              'Could not load ticket',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadTicket();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(BuildContext context) {
    final ticket = _ticket!;
    final isNightlife = ticket.serviceType.toLowerCase().contains('nightlife') ||
        ticket.serviceType.toLowerCase().contains('venue') ||
        ticket.serviceType.toLowerCase().contains('experience');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Venue name
          Text(
            ticket.venueName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.serviceType,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // QR code with pulsing background + live clock overlay
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: isNightlife ? AppTheme.nightGradient : AppTheme.emeraldGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.emerald.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Live clock — proves this is a live app, not a screenshot
                _LiveClockDisplay(now: _clockNow),
                const SizedBox(height: 16),

                // QR code with pulsing background
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing background ring
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, child) => Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: _pulseAnimation.value),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // QR code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: ticket.passToken,
                        version: QrVersions.auto,
                        size: 220,
                        gapless: true,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Anti-screenshot hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_clock, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Live QR — screenshots will be rejected',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Booking details card
          _DetailRow(label: 'Guests', value: '${ticket.seatCount}'),
          _DetailRow(label: 'Cover Charge', value: '₹${ticket.totalAmount.toStringAsFixed(0)}'),
          _DetailRow(
            label: 'Scheduled',
            value: '${ticket.scheduledFor.day}/${ticket.scheduledFor.month}/${ticket.scheduledFor.year} '
                '${ticket.scheduledFor.hour}:${ticket.scheduledFor.minute.toString().padLeft(2, '0')}',
          ),
          _DetailRow(label: 'Status', value: ticket.status),
          const SizedBox(height: 16),

          // Instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.emerald, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show this QR code to the bouncer at the entry. The clock above must be '
                    'ticking — if it\'s frozen, the bouncer will reject it as a screenshot.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A live digital clock display with seconds ticking. Rendered on top of
/// the QR code so that a screenshot would freeze the clock, allowing the
/// bouncer to detect screenshot fraud before even scanning.
class _LiveClockDisplay extends StatelessWidget {
  const _LiveClockDisplay({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          '$hour:$minute:$second',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        // Pulsing dot to prove the clock is live
        _PulsingDot(),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Opacity(
        opacity: 0.3 + (_controller.value * 0.7),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

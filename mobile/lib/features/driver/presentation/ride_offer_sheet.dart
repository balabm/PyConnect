import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_signalr_provider.dart';

/// Bottom sheet that shows an incoming ride offer to the driver with
/// a countdown timer. Auto-declines when the timer expires.
class RideOfferSheet extends StatefulWidget {
  const RideOfferSheet({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });

  final RideOfferModel offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<RideOfferSheet> createState() => _RideOfferSheetState();
}

class _RideOfferSheetState extends State<RideOfferSheet> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.offer.expiresIn > 0 ? widget.offer.expiresIn : 30;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        widget.onDecline();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / (widget.offer.expiresIn > 0 ? widget.offer.expiresIn : 30);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // New ride offer header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.local_taxi, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Text('New Ride Offer!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          if (widget.offer.isSos) ...[
            const SizedBox(height: 8),
            const StatusBadge(
              label: 'SOS Ride — Higher payout',
              variant: BadgeVariant.danger,
              icon: Icons.warning,
            ),
          ],
          const SizedBox(height: 20),
          // Countdown progress
            ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(_secondsLeft <= 5 ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('$_secondsLeft seconds to respond', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 20),
          // Route info
          _RouteRow(icon: Icons.my_location, color: AppTheme.sky, text: widget.offer.pickupAddress),
          Padding(padding: const EdgeInsets.only(left: 10), child: Container(width: 2, height: 20, color: Theme.of(context).dividerColor)),
          _RouteRow(icon: Icons.location_on, color: Theme.of(context).colorScheme.secondary, text: widget.offer.dropoffAddress),
          const SizedBox(height: 20),
          // Ride details
          Row(
            children: [
              _DetailChip(icon: Icons.straighten, label: '${widget.offer.distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(width: 8),
              _DetailChip(icon: Icons.payment, label: widget.offer.paymentMethod),
              const SizedBox(width: 8),
              _DetailChip(icon: Icons.motorcycle, label: widget.offer.vehicleType),
            ],
          ),
          if (widget.offer.surgeMultiplier > 1.0) ...[
            const SizedBox(height: 8),
            StatusBadge(
              label: 'Surge ${widget.offer.surgeMultiplier}x · ${widget.offer.surgeReason ?? "High demand"}',
              variant: BadgeVariant.warning,
            ),
          ],
          const SizedBox(height: 24),
          // Earnings highlight
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Your Earnings (100%)', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
                Text('\u20B9${widget.offer.driverEarnings.toStringAsFixed(0)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    AppHaptics.heavy();
                    _countdownTimer?.cancel();
                    widget.onDecline();
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.secondary, side: BorderSide(color: Theme.of(context).colorScheme.secondary)),
                  child: const Padding(padding: EdgeInsets.all(16), child: Text('Decline', style: TextStyle(fontSize: 16))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    AppHaptics.success();
                    _countdownTimer?.cancel();
                    widget.onAccept();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                  child: const Padding(padding: EdgeInsets.all(16), child: Text('Accept', style: TextStyle(fontSize: 16))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
    ]);
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Helper to show the ride offer sheet.
void showRideOfferSheet(BuildContext context, RideOfferModel offer, {required VoidCallback onAccept, required VoidCallback onDecline}) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => RideOfferSheet(offer: offer, onAccept: onAccept, onDecline: onDecline),
  );
}

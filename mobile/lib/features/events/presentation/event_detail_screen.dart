import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../data/p2p_event_api.dart';

/// Event detail screen — shows event info, ticket purchase, and host actions.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  P2pEventModel? _event;
  bool _loading = true;
  String? _error;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await ref.read(p2pEventApiProvider).getBySlug(widget.slug);
      if (mounted) {
        setState(() {
          _event = event;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _buyTicket() async {
    final event = _event;
    if (event == null) return;

    AppHaptics.light();
    setState(() => _purchasing = true);

    try {
      final result = await ref.read(p2pEventApiProvider).buyTicket(event.id);

      if (event.isFree) {
        // Free event — ticket issued immediately
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('RSVP confirmed! See you there.'),
              backgroundColor: AppTheme.emerald,
            ),
          );
          await _loadEvent();
        }
      } else {
        // Paid event — launch Razorpay checkout, then confirm the ticket.
        final razorpayOrderId = result.razorpayOrderId;
        if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Could not create payment order. Please try again.'),
                backgroundColor: AppTheme.danger,
              ),
            );
          }
          return;
        }
        await _launchRazorpayAndConfirm(
          ticketId: result.ticketId,
          razorpayOrderId: razorpayOrderId,
          amount: result.pricePaid > 0 ? result.pricePaid : event.entryPrice,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  /// Launches Razorpay checkout for a paid event ticket and confirms the
  /// ticket on the backend once payment succeeds.
  Future<void> _launchRazorpayAndConfirm({
    required String ticketId,
    required String razorpayOrderId,
    required double amount,
  }) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    // Ensure the Razorpay SDK is initialized.
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
          // Confirm the ticket on the backend with the Razorpay payment details.
          try {
            await ref.read(p2pEventApiProvider).confirmTicket(
                  ticketId: ticketId,
                  razorpayOrderId: orderId,
                  razorpayPaymentId: paymentId,
                  signature: signature ?? '',
                );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Ticket confirmed! Check your wallet.'),
                  backgroundColor: AppTheme.emerald,
                ),
              );
              await _loadEvent();
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
          // External wallet selected — user completed payment elsewhere.
          // We still attempt to confirm in case the webhook already reconciled.
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
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadEvent)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final event = _event!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              event.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.coral.withValues(alpha: 0.8), AppTheme.coralLight.withValues(alpha: 0.4)],
                ),
              ),
              child: const Icon(Icons.celebration, size: 64, color: Colors.white70),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges
                Row(
                  children: [
                    _Badge(
                      label: event.status,
                      color: event.status == 'Published' ? AppTheme.emerald : AppTheme.warning,
                    ),
                    const SizedBox(width: 8),
                    if (event.isSoldOut)
                      _Badge(label: 'SOLD OUT', color: AppTheme.danger)
                    else
                      _Badge(label: '${event.spotsLeft} spots left', color: AppTheme.info),
                  ],
                ),
                const SizedBox(height: 16),

                // Date & time
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: '${_fmtDate(event.startsAt)} — ${_fmtDate(event.endsAt)}',
                ),
                const SizedBox(height: 8),

                // Location
                if (event.address != null)
                  _InfoRow(icon: Icons.location_on, label: event.address!),

                // Price
                const SizedBox(height: 16),
                Row(
                  children: [
                    _PriceTag(
                      label: event.isFree ? 'FREE' : '₹${event.entryPrice.toStringAsFixed(0)}',
                      color: event.isFree ? AppTheme.emerald : AppTheme.coral,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${event.ticketsSold}/${event.capacityLimit} attending',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),

                // Description
                if (event.description != null) ...[
                  const SizedBox(height: 24),
                  const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(event.description!),
                ],

                // What's offered
                if (event.whatsOffered != null) ...[
                  const SizedBox(height: 24),
                  const Text("What's Offered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(event.whatsOffered!),
                  ),
                ],

                const SizedBox(height: 32),

                // Action buttons
                if (event.isHost) ...[
                  // Host actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AppHaptics.light();
                            context.push('/events/${event.id}/attendees');
                          },
                          icon: const Icon(Icons.people),
                          label: const Text('Attendees'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.info,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AppHaptics.light();
                            context.push('/events/${event.id}/scan');
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Guests'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (event.status == 'Published' && !event.isSoldOut) ...[
                  // Guest action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _purchasing ? null : _buyTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _purchasing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(event.isFree ? Icons.check : Icons.local_activity),
                      label: Text(
                        event.isFree ? 'RSVP Now' : 'Buy Ticket — ₹${event.entryPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

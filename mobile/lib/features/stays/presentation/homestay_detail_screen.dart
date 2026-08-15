import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/stays_providers.dart';
import '../data/stays_api.dart';

class HomestayDetailScreen extends ConsumerStatefulWidget {
  const HomestayDetailScreen({super.key, required this.homestayId});

  final String homestayId;

  @override
  ConsumerState<HomestayDetailScreen> createState() =>
      _HomestayDetailScreenState();
}

class _HomestayDetailScreenState extends ConsumerState<HomestayDetailScreen> {
  static const _heroImages = [
    'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
    'https://images.unsplash.com/photo-1580587774553-5e7e8a4f5d1c?w=800',
    'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
    'https://images.unsplash.com/photo-1600598546430-3a1e4e9d3e2c?w=800',
  ];

  String _heroImageFor(String name) {
    final hash = name.hashCode;
    return _heroImages[hash.abs() % _heroImages.length];
  }

  @override
  Widget build(BuildContext context) {
    final homestayAsync = ref.watch(homestayDetailProvider(widget.homestayId));
    final addOnEnabled = ref.watch(addOnToggleProvider);
    final guests = ref.watch(selectedGuestsProvider);

    return Scaffold(
      body: homestayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Error: $e',
          onRetry: () => ref.invalidate(homestayDetailProvider(widget.homestayId)),
        ),
        data: (homestay) {
          final basePrice = homestay.nightlyRate;
          const addOnPricePerDay = 300.0;
          final addOnTotal = addOnEnabled ? addOnPricePerDay : 0.0;
          final totalPrice = basePrice + addOnTotal;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: AppNetworkImage(
                    imageUrl: _heroImageFor(homestay.name),
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.home,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    AppHaptics.light();
                    context.pop();
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              homestay.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (homestay.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Verified',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.place, size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            homestay.locationArea,
                            style: TextStyle(
                                fontSize: 15,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Text(
                          '0% Booking Fee — You pay what the host charges',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        homestay.description,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Amenities',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (homestay.hasWifi)
                            _amenityChip(Icons.wifi, 'WiFi'),
                          _amenityChip(Icons.group, 'Up to ${homestay.maxGuests} guests'),
                          _amenityChip(Icons.bed, 'Private room'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _CompleteTripCard(
                        addOnEnabled: addOnEnabled,
                        onToggle: (value) {
                          AppHaptics.light();
                          ref.read(addOnToggleProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 24),
                      _PriceBreakdown(
                        basePrice: basePrice,
                        addOnTotal: addOnTotal,
                        total: totalPrice,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () {
                            AppHaptics.light();
                            _bookHomestay(
                                context, ref, homestay, guests, addOnEnabled);
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Slide to Book — ₹${totalPrice.toInt()}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _amenityChip(IconData icon, String label) {
    final chipColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: iconColor)),
        ],
      ),
    );
  }

  Future<void> _bookHomestay(
    BuildContext context,
    WidgetRef ref,
    Homestay homestay,
    int guests,
    bool addOnEnabled,
  ) async {
    final now = DateTime.now();
    final checkIn = now.add(const Duration(days: 1));
    final checkOut = now.add(const Duration(days: 3));

    final request = BookHomestayRequest(
      homestayId: homestay.id,
      checkIn:
          '${checkIn.year}-${checkIn.month.toString().padLeft(2, '0')}-${checkIn.day.toString().padLeft(2, '0')}',
      checkOut:
          '${checkOut.year}-${checkOut.month.toString().padLeft(2, '0')}-${checkOut.day.toString().padLeft(2, '0')}',
      guests: guests,
      addScooterPickup: addOnEnabled,
      addLuggageCloak: addOnEnabled,
    );

    try {
      final response =
          await ref.read(staysApiProvider).book(request);
      if (context.mounted) {
        _showBookingConfirmation(context, response);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    }
  }

  void _showBookingConfirmation(
      BuildContext context, BookHomestayResponse response) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, size: 40, color: Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Booking Confirmed!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Pass Token',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    response.passToken,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount'),
                Text(
                  '\u20B9${response.totalAmount.toInt()}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${response.status}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
            if (response.suggestedAddOns.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Suggested Add-ons',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...response.suggestedAddOns.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          a.isFree ? Icons.card_giftcard : Icons.add_circle,
                          size: 16,
                          color: a.isFree ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.name, style: const TextStyle(fontSize: 13))),
                        if (a.isFree)
                          const Text('Free', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600))
                        else
                          Text('\u20B9${a.price.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  AppHaptics.light();
                  Navigator.of(context).pop();
                  context.go('/stays');
                },
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _CompleteTripCard extends StatelessWidget {
  const _CompleteTripCard({
    required this.addOnEnabled,
    required this.onToggle,
  });

  final bool addOnEnabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade50,
            Colors.amber.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.luggage, size: 24, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Complete Your Trip',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              Switch(
                value: addOnEnabled,
                onChanged: onToggle,
                activeThumbColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add a Scooter & Luggage Drop for just ₹300/day',
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            addOnEnabled
                ? 'Bundle added — save 10% on scooter pickup + free luggage cloak'
                : 'Toggle to add scooter pickup (10% off) + early luggage drop (free)',
            style: TextStyle(
              fontSize: 12,
              color: addOnEnabled
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.basePrice,
    required this.addOnTotal,
    required this.total,
  });

  final double basePrice;
  final double addOnTotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _priceRow(context, 'Stay (1 night)', '₹${basePrice.toInt()}'),
          if (addOnTotal > 0) ...[
            const SizedBox(height: 8),
            _priceRow(context, 'Scooter + Luggage Bundle', '₹${addOnTotal.toInt()}'),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '₹${total.toInt()}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

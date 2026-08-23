import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart' hide staysApiProvider;
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

  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  final _pageController = PageController();
  int _galleryPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(razorpayPaymentProvider).init();
    });
  }

  String _heroImageFor(String name) {
    final hash = name.hashCode;
    return _heroImages[hash.abs() % _heroImages.length];
  }

  List<String> _resolveImages(Homestay homestay) {
    if (homestay.imageUrls != null && homestay.imageUrls!.isNotEmpty) {
      return homestay.imageUrls!;
    }
    return [_heroImageFor(homestay.name)];
  }

  int get _nights {
    if (_checkInDate == null || _checkOutDate == null) return 1;
    return _checkOutDate!.difference(_checkInDate!).inDays.clamp(1, 30);
  }

  Future<void> _pickCheckIn(List<DateTime> unavailableDates) async {
    final unavailableSet = unavailableDates
        .map((d) => DateUtils.dateOnly(d))
        .toSet();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkInDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        final dateOnly = DateUtils.dateOnly(day);
        return !unavailableSet.contains(dateOnly);
      },
    );
    if (picked != null) {
      AppHaptics.light();
      setState(() {
        _checkInDate = picked;
        if (_checkOutDate != null && _checkOutDate!.isBefore(picked.add(const Duration(days: 1)))) {
          _checkOutDate = picked.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickCheckOut(List<DateTime> unavailableDates) async {
    if (_checkInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in date first')),
      );
      return;
    }
    final unavailableSet = unavailableDates
        .map((d) => DateUtils.dateOnly(d))
        .toSet();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOutDate ?? _checkInDate!.add(const Duration(days: 1)),
      firstDate: _checkInDate!.add(const Duration(days: 1)),
      lastDate: _checkInDate!.add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime day) {
        final dateOnly = DateUtils.dateOnly(day);
        return !unavailableSet.contains(dateOnly);
      },
    );
    if (picked != null) {
      AppHaptics.light();
      setState(() => _checkOutDate = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          final images = _resolveImages(homestay);
          final basePrice = homestay.nightlyRate * _nights;
          const addOnPricePerDay = 300.0;
          final addOnTotal = addOnEnabled ? addOnPricePerDay * _nights : 0.0;
          final totalPrice = basePrice + addOnTotal;

          return CustomScrollView(
            slivers: [
              // Image Gallery
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                floating: false,
                snap: false,
                backgroundColor: AppTheme.night,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    homestay.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  collapseMode: CollapseMode.parallax,
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _galleryPage = i),
                        itemBuilder: (context, i) => AppNetworkImage(
                          imageUrl: images[i],
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.home,
                        ),
                      ),
                      // Page dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (i) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _galleryPage ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _galleryPage
                                      ? AppTheme.emerald
                                      : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
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
                      // Title + Verified badge
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
                          color: AppTheme.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          '0% Booking Fee — You pay what the host charges',
                          style: TextStyle(
                            color: AppTheme.success,
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
                      const SizedBox(height: 24),

                      // Check-in / Check-out date pickers
                      _SectionTitle(icon: Icons.calendar_today, title: 'Select Dates'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateCard(
                              label: 'Check-in',
                              date: _formatDate(_checkInDate),
                              onTap: () => _pickCheckIn(homestay.unavailableDates),
                              icon: Icons.login,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateCard(
                              label: 'Check-out',
                              date: _formatDate(_checkOutDate),
                              onTap: () => _pickCheckOut(homestay.unavailableDates),
                              icon: Icons.logout,
                            ),
                          ),
                        ],
                      ),
                      if (_checkInDate != null && _checkOutDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$_nights night${_nights > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Guest counter
                      _SectionTitle(icon: Icons.people, title: 'Guests'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filled(
                            onPressed: guests > 1
                                ? () {
                                    AppHaptics.light();
                                    ref.read(selectedGuestsProvider.notifier).state = guests - 1;
                                  }
                                : null,
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '$guests guest${guests > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                          IconButton.filled(
                            onPressed: guests < homestay.maxGuests
                                ? () {
                                    AppHaptics.light();
                                    ref.read(selectedGuestsProvider.notifier).state = guests + 1;
                                  }
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                          const Spacer(),
                          Text(
                            'Max ${homestay.maxGuests}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Amenities
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
                          _amenityChip(Icons.ac_unit, 'AC'),
                          _amenityChip(Icons.kitchen, 'Kitchen access'),
                          _amenityChip(Icons.local_parking, 'Free parking'),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Host Details
                      _SectionTitle(icon: Icons.person, title: 'Host Details'),
                      const SizedBox(height: 12),
                      _InfoCard(
                        icon: Icons.account_circle,
                        title: 'Verified Host',
                        subtitle: 'Response time: within an hour',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${homestay.isVerified ? "4.8" : "4.5"} \u2605',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.emerald,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // House Rules
                      _SectionTitle(icon: Icons.gavel, title: 'House Rules'),
                      const SizedBox(height: 8),
                      _HouseRulesCard(),
                      const SizedBox(height: 24),

                      // Timings
                      _SectionTitle(icon: Icons.access_time, title: 'Check-in / Check-out'),
                      const SizedBox(height: 8),
                      _TimingsCard(),
                      const SizedBox(height: 24),

                      // Complete Trip add-on
                      _CompleteTripCard(
                        addOnEnabled: addOnEnabled,
                        onToggle: (value) {
                          AppHaptics.light();
                          ref.read(addOnToggleProvider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Price breakdown with nights
                      _PriceBreakdown(
                        basePrice: basePrice,
                        nights: _nights,
                        addOnTotal: addOnTotal,
                        total: totalPrice,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _checkInDate == null || _checkOutDate == null
                              ? null
                              : () {
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
                            _checkInDate == null || _checkOutDate == null
                                ? 'Select dates to book'
                                : 'Book Now — ₹${totalPrice.toInt()}',
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
    final checkIn = _checkInDate!;
    final checkOut = _checkOutDate!;

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
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, size: 40, color: AppTheme.success),
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
                    'Stay Pass',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: response.passToken,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
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
                          color: a.isFree ? AppTheme.success : AppTheme.emerald,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.name, style: const TextStyle(fontSize: 13))),
                        if (a.isFree)
                          const Text('Free', style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.w600))
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.emerald),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.date,
    required this.onTap,
    required this.icon,
  });
  final String label;
  final String date;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppTheme.emerald),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _HouseRulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rules = <(IconData, String)>[
      (Icons.access_time, 'Check-in after 2:00 PM'),
      (Icons.logout, 'Check-out before 11:00 AM'),
      (Icons.smoke_free, 'No smoking inside the property'),
      (Icons.do_not_disturb, 'Pets are not allowed'),
      (Icons.nightlight, 'Quiet hours after 10:00 PM'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: rules.map((rule) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(rule.$1, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(child: Text(rule.$2, style: TextStyle(fontSize: 14, height: 1.4, color: Theme.of(context).colorScheme.onSurface))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimingsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _timingRow(context, Icons.login, 'Check-in', '2:00 PM - 8:00 PM'),
          const SizedBox(height: 12),
          _timingRow(context, Icons.logout, 'Check-out', '8:00 AM - 11:00 AM'),
        ],
      ),
    );
  }

  Widget _timingRow(BuildContext context, IconData icon, String label, String time) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.emerald),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(time, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A2E1F), const Color(0xFF0D1A12)]
              : [const Color(0xFFF0F7F2), const Color(0xFFE8F5EE)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: addOnEnabled ? 0.6 : 0.2),
          width: addOnEnabled ? 1.5 : 1,
        ),
        boxShadow: addOnEnabled
            ? [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.luggage, size: 20, color: AppTheme.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Trip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scooter + Luggage Drop · ₹300/day',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              // Sleek pill button instead of Switch
              GestureDetector(
                onTap: () => onToggle(!addOnEnabled),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: addOnEnabled
                        ? AppTheme.emerald
                        : (isDark ? Colors.white10 : AppTheme.emerald.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: addOnEnabled ? AppTheme.emerald : AppTheme.emerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    addOnEnabled ? '✓ Added' : '+ Add Bundle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: addOnEnabled ? Colors.white : AppTheme.emerald,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (addOnEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppTheme.emerald.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save 10% on scooter pickup + free luggage cloak',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.basePrice,
    required this.nights,
    required this.addOnTotal,
    required this.total,
  });

  final double basePrice;
  final int nights;
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
          _priceRow(context, 'Stay ($nights night${nights > 1 ? 's' : ''})', '₹${basePrice.toInt()}'),
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

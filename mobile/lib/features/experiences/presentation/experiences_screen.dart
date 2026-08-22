import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../../auth/presentation/quick_auth_sheet.dart';
import '../../venues/application/venue_controller.dart';
import '../../venues/data/venue_api.dart';

/// Experiences & Safety: Auroville/Matrimandir scheduling, French Quarter
/// walks, plus static safety guidance.
class ExperiencesScreen extends ConsumerWidget {
  const ExperiencesScreen({super.key});

  static const _safety = [
    _SafetyInfo(
      icon: Icons.beach_access,
      color: Color(0xFF2A9D8F),
      title: 'Beach Safety Zones',
      text: 'Promenade, Paradise and Auroville beaches have designated safe-swim zones. Avoid swimming past float lines or during rough monsoon seas.',
    ),
    _SafetyInfo(
      icon: Icons.two_wheeler,
      color: Color(0xFFF4A261),
      title: 'Scooter Parking Rules',
      text: 'Park only in marked bays along Rock Beach; improper parking near RP Road attracts tows and fines. Helmets are compulsory.',
    ),
    _SafetyInfo(
      icon: Icons.emergency,
      color: Color(0xFFE76F51),
      title: 'Emergency Contacts',
      text: 'Police 100 · Ambulance 108/112 · Coast Guard 1554 · Women helpline 1091. Pondicherry is a no-liquor-in-public city.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experiences = ref.watch(experiencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Experiences & Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: SectionHeader(
              icon: Icons.explore,
              title: 'Bookable Experiences',
            ),
          ),
          const SizedBox(height: 12),
          experiences.when(
            loading: () => const SkeletonList(type: SkeletonType.homeVibe, count: 3),
            error: (e, _) => ErrorState(
              message: 'Could not load experiences: $e',
              onRetry: () => ref.invalidate(experiencesProvider),
            ),
            data: (venues) => venues.isEmpty
                ? const EmptyState(
                    icon: Icons.explore_off,
                    title: 'No bookable experiences yet',
                    subtitle: 'Check back soon for new experiences.',
                  )
                : Column(
                    children: [
                      for (int i = 0; i < venues.length; i++)
                        FadeSlideIn(
                          delay: Duration(milliseconds: i * 100),
                          child: _ExperienceCard(venue: venues[i]),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: SectionHeader(
              icon: Icons.shield,
              title: 'Safety & Guidelines',
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _safety.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 400 + i * 100),
              child: _SafetyCard(info: _safety[i]),
            ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends ConsumerWidget {
  const _ExperienceCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authTokenProvider) != null;

    return AppCard(
      imageUrl: venue.imageUrl,
      imageHeight: 120,
      gradient: LinearGradient(
        colors: [AppTheme.emerald.withValues(alpha: 0.6), AppTheme.emerald],
      ),
      badge: StatusBadge(
        label: venue.isOpen ? 'Open' : 'Closed',
        variant: venue.isOpen ? BadgeVariant.success : BadgeVariant.danger,
        icon: venue.isOpen ? Icons.circle : Icons.cancel,
      ),
      onTap: authed
          ? () { AppHaptics.light(); _openBooking(context, ref); }
          : () { AppHaptics.light(); ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Log in to book an experience.')),
            ); },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  venue.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (venue.rating != null)
                RatingStars(rating: venue.rating!, reviewCount: venue.reviewCount),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.place, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  venue.address ?? 'Puducherry',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openBooking(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExperienceBookingSheet(venue: venue),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience booked! Check your profile.')),
      );
    }
  }
}

class _ExperienceBookingSheet extends ConsumerStatefulWidget {
  const _ExperienceBookingSheet({required this.venue});

  final Venue venue;

  @override
  ConsumerState<_ExperienceBookingSheet> createState() => _ExperienceBookingSheetState();
}

class _ExperienceBookingSheetState extends ConsumerState<_ExperienceBookingSheet> {
  DateTime _when = DateTime.now().add(const Duration(days: 1));
  int _guests = 2;
  bool _submitting = false;
  String? _error;

  static const _perPerson = 150.0;

  double get _total => _perPerson * _guests;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Book ${widget.venue.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: AppTheme.emerald),
            title: const Text('Date'),
            subtitle: Text('${_when.day}/${_when.month}/${_when.year} 10:00'),
            trailing: const Icon(Icons.edit_calendar, color: AppTheme.emerald),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _when,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
              );
              if (picked == null || !context.mounted) return;
              setState(() => _when = picked);
            },
          ),
          Row(children: [
            const Text('Guests'),
            const Spacer(),
            IconButton(onPressed: _guests > 1 ? () => setState(() => _guests--) : null, icon: const Icon(Icons.remove_circle_outline, color: AppTheme.emerald)),
            Text('$_guests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(onPressed: _guests < 12 ? () => setState(() => _guests++) : null, icon: const Icon(Icons.add_circle_outline, color: AppTheme.emerald)),
          ]),
          Text('Total: \u20B9${_total.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                : const Text('Confirm booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Check auth — if not signed in, show QuickAuthSheet before proceeding
    final isAuthed = ref.read(authTokenProvider)?.isNotEmpty ?? false;
    if (!isAuthed) {
      final authenticated = await QuickAuthSheet.show(
        context,
        ref,
        title: 'Sign in to book',
      );
      if (authenticated != true || !mounted) return;
    }

    setState(() { _submitting = true; _error = null; });
    final scheduledFor = DateTime(_when.year, _when.month, _when.day, 10);
    try {
      await ref.read(bookingApiProvider).create(
        venueId: widget.venue.id,
        seats: _guests,
        scheduledFor: scheduledFor,
        notes: 'Experience booking',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SafetyInfo {
  const _SafetyInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.info});

  final _SafetyInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: info.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(info.icon, color: info.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: info.color,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  info.text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
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
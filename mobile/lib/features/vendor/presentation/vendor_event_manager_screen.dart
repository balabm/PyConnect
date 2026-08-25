import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/p2p_event_api.dart';

/// Shared text-field builder matching the vendor menu screen style.
Widget _buildEventField(
  BuildContext context,
  TextEditingController controller,
  String label, {
  String? hintText,
  IconData? prefixIcon,
  TextInputType? keyboardType,
  int maxLines = 1,
  required ValueChanged<String> onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
      ),
    ),
  );
}

/// Maps an event status string to a [BadgeVariant] + display label.
BadgeVariant _statusVariant(String status) {
  switch (status.toLowerCase()) {
    case 'published':
      return BadgeVariant.success;
    case 'completed':
      return BadgeVariant.info;
    case 'cancelled':
      return BadgeVariant.danger;
    case 'draft':
    default:
      return BadgeVariant.warning;
  }
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
      '${two(dt.hour)}:${two(dt.minute)}';
}

class VendorEventManagerScreen extends ConsumerStatefulWidget {
  const VendorEventManagerScreen({super.key});

  @override
  ConsumerState<VendorEventManagerScreen> createState() =>
      _VendorEventManagerScreenState();
}

class _VendorEventManagerScreenState
    extends ConsumerState<VendorEventManagerScreen> {
  List<P2pEventModel> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await ref.read(p2pEventApiProvider).myEvents();
      // Sort: upcoming first (by startsAt ascending), then past.
      events.sort((a, b) {
        final aUpcoming = a.endsAt.isAfter(DateTime.now());
        final bUpcoming = b.endsAt.isAfter(DateTime.now());
        if (aUpcoming != bUpcoming) {
          return aUpcoming ? -1 : 1;
        }
        return a.startsAt.compareTo(b.startsAt);
      });
      if (mounted) {
        setState(() {
          _events = events;
          _loading = false;
        });
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

  void _showCreateSheet() {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateEventSheet(),
    ).then((created) {
      if (created == true) {
        _loadEvents();
      }
    });
  }

  Future<void> _publishEvent(P2pEventModel event) async {
    AppHaptics.light();
    try {
      await ref.read(p2pEventApiProvider).publishEvent(event.id);
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${event.title}" is now live'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _cancelEvent(P2pEventModel event) async {
    AppHaptics.light();
    try {
      await ref.read(p2pEventApiProvider).cancelEvent(event.id);
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${event.title}" cancelled'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _confirmCancel(P2pEventModel event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          'Cancel Event?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Cancelling "${event.title}" will stop new ticket sales. '
          'Existing ticket holders will be notified. This cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelEvent(event);
            },
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming =
        _events.where((e) => e.endsAt.isAfter(now)).toList();
    final past = _events.where((e) => !e.endsAt.isAfter(now)).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Event Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              _loadEvents();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
        backgroundColor: AppTheme.emerald,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const ShimmerList(withImage: false, count: 6)
          : _error != null
              ? ErrorState(
                  message: 'Failed to load events: $_error',
                  onRetry: _loadEvents,
                )
              : _events.isEmpty
                  ? EmptyState(
                      icon: Icons.event_available,
                      title: 'No events yet',
                      subtitle:
                          'Tap "Create Event" to publish your first night.',
                      actionLabel: 'Create Event',
                      onAction: _showCreateSheet,
                    )
                  : RefreshIndicator(
                      color: AppTheme.emerald,
                      onRefresh: _loadEvents,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          if (upcoming.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Text(
                                'Upcoming (${upcoming.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...upcoming.map(
                              (e) => _EventCard(
                                event: e,
                                onPublish: () => _publishEvent(e),
                                onCancel: () => _confirmCancel(e),
                              ),
                            ),
                          ],
                          if (past.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              child: Text(
                                'Past (${past.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...past.map(
                              (e) => _EventCard(
                                event: e,
                                onPublish: () => _publishEvent(e),
                                onCancel: () => _confirmCancel(e),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onPublish,
    required this.onCancel,
  });

  final P2pEventModel event;
  final VoidCallback onPublish;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDraft = event.status.toLowerCase() == 'draft';
    final isPublished = event.status.toLowerCase() == 'published';
    final isPast = event.endsAt.isBefore(DateTime.now());

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event,
                  color: AppTheme.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDateTime(event.startsAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                color: Theme.of(context).colorScheme.surface,
                onSelected: (value) {
                  AppHaptics.light();
                  if (value == 'publish') onPublish();
                  if (value == 'cancel') onCancel();
                },
                itemBuilder: (_) => [
                  if (isDraft)
                    PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          const Icon(Icons.public, color: AppTheme.emerald, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Publish',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isPublished && !isPast)
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_outlined, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'Cancel Event',
                            style: TextStyle(color: AppTheme.danger),
                          ),
                        ],
                      ),
                    ),
                  if (!isDraft && !isPublished)
                    PopupMenuItem(
                      enabled: false,
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'No actions',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusBadge(
                label: event.status,
                variant: _statusVariant(event.status),
              ),
              const SizedBox(width: 8),
              if (event.isFree)
                StatusBadge(
                  label: 'Free RSVP',
                  variant: BadgeVariant.info,
                  icon: Icons.confirmation_num_outlined,
                )
              else
                StatusBadge(
                  label: '\u20B9${event.entryPrice.toStringAsFixed(0)} ticket',
                  variant: BadgeVariant.neutral,
                  icon: Icons.confirmation_num,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '${event.ticketsSold} / ${event.capacityLimit} sold',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              if (event.capacityLimit > 0)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (event.ticketsSold / event.capacityLimit)
                          .clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        event.isSoldOut
                            ? AppTheme.danger
                            : AppTheme.emerald,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (event.address != null && event.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.address!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateEventSheet extends ConsumerStatefulWidget {
  const _CreateEventSheet();

  @override
  ConsumerState<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<_CreateEventSheet> {
  final _titleController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _whatsOfferedController = TextEditingController();

  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isPaid = false;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _whatsOfferedController.dispose();
    super.dispose();
  }

  // Pondicherry center — used as default coordinates for venue events.
  static const double _defaultLat = 11.9356;
  static const double _defaultLng = 79.8301;

  Future<void> _pickStartsAt() async {
    AppHaptics.light();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? DateTime.now()),
    );
    if (pickedTime == null) return;
    setState(() {
      _startsAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickEndsAt() async {
    AppHaptics.light();
    final base = _endsAt ??
        _startsAt?.add(const Duration(hours: 3)) ??
        DateTime.now().add(const Duration(days: 1, hours: 3));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _startsAt ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (pickedTime == null) return;
    setState(() {
      _endsAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _startsAt != null &&
      _endsAt != null &&
      _endsAt!.isAfter(_startsAt!) &&
      (!_isPaid ||
          (double.tryParse(_priceController.text.trim()) ?? 0) > 0) &&
      (int.tryParse(_capacityController.text.trim()) ?? 0) > 0;

  Future<void> _submit() async {
    if (!_canSubmit) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
        ),
      );
      return;
    }

    final price = _isPaid
        ? (double.tryParse(_priceController.text.trim()) ?? 0)
        : 0.0;
    final capacity =
        int.tryParse(_capacityController.text.trim()) ?? 50;

    setState(() => _submitting = true);
    try {
      final api = ref.read(p2pEventApiProvider);
      final created = await api.createEvent(
        title: _titleController.text.trim(),
        startsAt: _startsAt!,
        endsAt: _endsAt!,
        latitude: _defaultLat,
        longitude: _defaultLng,
        entryPrice: price,
        capacityLimit: capacity,
        whatsOffered: _whatsOfferedController.text.trim().isEmpty
            ? null
            : _whatsOfferedController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      // Auto-publish per requirement: create then publish.
      await api.publishEvent(created.id);
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${created.title}" published successfully'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Event',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Publish a new night at your venue.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _buildEventField(
              context,
              _titleController,
              'Event Title *',
              hintText: 'e.g. Saturday Night Live',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Starts picker
            _DateTimePickerButton(
              label: 'Starts',
              value: _startsAt,
              onTap: _pickStartsAt,
            ),
            const SizedBox(height: 12),

            // Ends picker
            _DateTimePickerButton(
              label: 'Ends',
              value: _endsAt,
              onTap: _pickEndsAt,
              errorText: (_startsAt != null && _endsAt != null &&
                      _endsAt!.isBefore(_startsAt!))
                  ? 'End time must be after start time'
                  : null,
            ),
            const SizedBox(height: 12),

            _buildEventField(
              context,
              _addressController,
              'Location / Address',
              hintText: 'Venue address',
              prefixIcon: Icons.location_on_outlined,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Entry type segmented control
            Text(
              'Entry Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.card_giftcard, size: 14),
                  label: Text('Free RSVP'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.confirmation_num, size: 14),
                  label: Text('Paid Ticket'),
                ),
              ],
              selected: {_isPaid},
              onSelectionChanged: (v) {
                AppHaptics.selection();
                setState(() => _isPaid = v.first);
              },
            ),
            if (_isPaid) ...[
              const SizedBox(height: 12),
              _buildEventField(
                context,
                _priceController,
                'Ticket Price (\u20B9) *',
                hintText: 'e.g. 500',
                prefixIcon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            _buildEventField(
              context,
              _capacityController,
              'Capacity Limit *',
              hintText: 'e.g. 100',
              prefixIcon: Icons.people_outline,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _buildEventField(
              context,
              _whatsOfferedController,
              "What's Offered",
              hintText: 'e.g. Welcome drink, DJ set, hookah...',
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_submitting || !_canSubmit)
                    ? null
                    : () {
                        AppHaptics.medium();
                        _submit();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.emerald.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Publish Event',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimePickerButton extends StatelessWidget {
  const _DateTimePickerButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: errorText != null
                ? AppTheme.danger
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    hasValue ? _formatDateTime(value!) : 'Tap to pick date & time',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.danger,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

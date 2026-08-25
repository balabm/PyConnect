import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../data/p2p_event_api.dart';

/// Create Party screen — a clean one-page form for creating a P2P event.
///
/// Fields: title, date/time, location, entry price (free/paid), capacity,
/// what's offered, and a publish button. Calls POST /api/p2p-events.
class CreatePartyScreen extends ConsumerStatefulWidget {
  const CreatePartyScreen({super.key});

  @override
  ConsumerState<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends ConsumerState<CreatePartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '30');
  final _priceCtrl = TextEditingController(text: '0');
  final _offeredCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _startsError;
  String? _endsError;
  double _lat = 11.9356;
  double _lng = 79.8301;
  bool _isPaid = false;
  bool _publishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _offeredCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startsAt = dt;
        _startsError = null;
        if (_endsAt == null || _endsAt!.isBefore(dt)) {
          _endsAt = dt.add(const Duration(hours: 3));
          _endsError = null;
        }
      } else {
        _endsAt = dt;
        _endsError = null;
      }
    });
  }

  Future<void> _publish() async {
    // Validate inline form fields
    final formValid = _formKey.currentState?.validate() ?? false;

    // Validate date/time fields with inline errors
    setState(() {
      _startsError = _startsAt == null ? 'Please select a start date and time' : null;
      _endsError = _endsAt == null
          ? 'Please select an end date and time'
          : (_endsAt!.isBefore(_startsAt!) ? 'End time must be after start time' : null);
    });

    if (!formValid || _startsAt == null || _endsAt == null || _endsAt!.isBefore(_startsAt!)) {
      return;
    }

    final capacity = int.tryParse(_capacityCtrl.text) ?? 0;
    final price = _isPaid ? (double.tryParse(_priceCtrl.text) ?? 0) : 0.0;

    AppHaptics.light();
    setState(() => _publishing = true);

    try {
      final api = ref.read(p2pEventApiProvider);
      final event = await api.createEvent(
        title: _titleCtrl.text.trim(),
        startsAt: _startsAt!,
        endsAt: _endsAt!,
        latitude: _lat,
        longitude: _lng,
        entryPrice: price,
        capacityLimit: capacity,
        whatsOffered: _offeredCtrl.text.trim().isEmpty ? null : _offeredCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      // Publish the event immediately
      await api.publishEvent(event.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Event published! Share the link with your guests.'),
            backgroundColor: AppTheme.emerald,
            duration: const Duration(seconds: 3),
          ),
        );
        context.go('/events/${event.slug}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to create event: $e');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'e.g. Auroville Villa Sunset Mix',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date & Time
              _DateTimeTile(
                label: 'Starts',
                value: _startsAt,
                errorText: _startsError,
                onTap: () => _pickDateTime(isStart: true),
              ),
              const SizedBox(height: 12),
              _DateTimeTile(
                label: 'Ends',
                value: _endsAt,
                errorText: _endsError,
                onTap: () => _pickDateTime(isStart: false),
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  hintText: 'e.g. Auroville Road, White Town',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),

              // Entry type
              const Text('Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.card_giftcard),
                    label: Text('Free RSVP'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.payments),
                    label: Text('Paid Ticket'),
                  ),
                ],
                selected: {_isPaid},
                onSelectionChanged: (s) => setState(() => _isPaid = s.first),
              ),
              const SizedBox(height: 16),

              if (_isPaid)
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ticket Price (₹)',
                    hintText: 'e.g. 500',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (_isPaid) {
                      final price = double.tryParse(value ?? '') ?? 0;
                      if (price <= 0) return 'Paid events must have a price greater than 0';
                    }
                    return null;
                  },
                ),
              if (_isPaid) const SizedBox(height: 16),

              // Capacity
              TextFormField(
                controller: _capacityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacity Limit',
                  hintText: 'e.g. 30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final capacity = int.tryParse(value ?? '') ?? 0;
                  if (capacity <= 0) return 'Capacity must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // What's offered
              TextFormField(
                controller: _offeredCtrl,
                decoration: const InputDecoration(
                  labelText: "What's Offered",
                  hintText: 'e.g. Pool access, BYOB, techno DJ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Publish
              ElevatedButton.icon(
                onPressed: _publishing ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                icon: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.publish),
                label: const Text(
                  'Publish Event',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({required this.label, required this.value, required this.onTap, this.errorText});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasError ? AppTheme.danger : Theme.of(context).colorScheme.outline,
            width: hasError ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.event, color: hasError ? AppTheme.danger : AppTheme.emerald),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    value != null
                        ? '${value!.day}/${value!.month}/${value!.year} ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
                        : 'Tap to select',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 4),
                    Text(errorText!, style: TextStyle(fontSize: 12, color: AppTheme.danger)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

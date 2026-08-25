import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Shows a modal bottom sheet for logging a manual guest entry at the door.
/// Used by Pub/Club bouncers when a guest walks in without a digital ticket.
void showManualDoorLogSheet(BuildContext context, WidgetRef ref, String venueId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ManualDoorLogSheet(venueId: venueId),
  );
}

class _ManualDoorLogSheet extends ConsumerStatefulWidget {
  const _ManualDoorLogSheet({required this.venueId});
  final String venueId;

  @override
  ConsumerState<_ManualDoorLogSheet> createState() => _ManualDoorLogSheetState();
}

class _ManualDoorLogSheetState extends ConsumerState<_ManualDoorLogSheet> {
  String _guestType = 'Male';
  String _entryType = 'Cash';
  final _coverController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _coverController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      await ref.read(vendorDashboardApiProvider).manualDoorLog(
            venueId: widget.venueId,
            guestType: _guestType,
            entryType: _entryType,
            coverCollected: _entryType == 'VIP' ? 0 : (double.tryParse(_coverController.text.trim()) ?? 0),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged: $_guestType — ${_entryType == 'VIP' ? 'VIP Free Entry' : '₹${_coverController.text.trim()}'}'),
            backgroundColor: AppTheme.emerald,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
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
        left: 16, right: 16, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Manual Door Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('Log a walk-in guest to keep occupancy accurate', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          // Guest Type
          Text('Guest Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Male', icon: Icon(Icons.man, size: 16), label: Text('Male')),
              ButtonSegment(value: 'Female', icon: Icon(Icons.woman, size: 16), label: Text('Female')),
              ButtonSegment(value: 'Couple', icon: Icon(Icons.people, size: 16), label: Text('Couple')),
            ],
            selected: {_guestType},
            onSelectionChanged: (v) {
              AppHaptics.light();
              setState(() => _guestType = v.first);
            },
          ),
          const SizedBox(height: 16),

          // Entry Type
          Text('Entry Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Cash', icon: Icon(Icons.payments, size: 16), label: Text('Paid Cash')),
              ButtonSegment(value: 'VIP', icon: Icon(Icons.star, size: 16), label: Text('VIP Free')),
            ],
            selected: {_entryType},
            onSelectionChanged: (v) {
              AppHaptics.light();
              setState(() => _entryType = v.first);
            },
          ),
          const SizedBox(height: 16),

          // Cover charge (only for Cash)
          if (_entryType == 'Cash') ...[
            TextField(
              controller: _coverController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cover Collected (₹)',
                prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.emerald),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Friend of the owner',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Logging...' : 'Log Entry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

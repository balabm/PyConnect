import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_api.dart';

class SosBottomSheet extends ConsumerStatefulWidget {
  const SosBottomSheet({super.key});

  @override
  ConsumerState<SosBottomSheet> createState() => _SosBottomSheetState();
}

class _SosBottomSheetState extends ConsumerState<SosBottomSheet> {
  bool _submitting = false;
  String? _selectedIssue;
  double? _latitude;
  double? _longitude;
  String? _gpsStatus;

  static final _issues = [
    ('Scooter Breakdown', Icons.two_wheeler, AppTheme.warning),
    ('Payment Issue', Icons.payment, AppTheme.info),
    ('Safety Concern', Icons.shield, AppTheme.danger),
  ];

  Future<void> _captureGps() async {
    setState(() => _gpsStatus = 'Capturing GPS...');
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _latitude = 11.9356;
      _longitude = 79.8301;
      _gpsStatus = 'GPS captured';
    });
  }

  @override
  void initState() {
    super.initState();
    _captureGps();
  }

  Future<void> _submit() async {
    if (_selectedIssue == null) return;

    setState(() => _submitting = true);

    try {
      final request = SosRequest(
        issue: _selectedIssue!,
        latitude: _latitude,
        longitude: _longitude,
      );

      await ref.read(supportApiProvider).createSos(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS sent! Our team has been alerted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(Icons.sos, size: 48, color: Colors.red.shade700),
          const SizedBox(height: 8),
          Text(
            'Emergency SOS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your issue. This will alert our team immediately.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ..._issues.map((issue) {
            final (label, icon, color) = issue;
            final isSelected = _selectedIssue == label;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _selectedIssue = label),
                  icon: Icon(icon, size: 28),
                  label: Text(label, style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSelected ? color.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
                    foregroundColor: color,
                    side: BorderSide(
                      color: isSelected ? color : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (_gpsStatus != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _latitude != null ? Icons.location_on : Icons.location_searching,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _gpsStatus!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting || _selectedIssue == null ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Sending...' : 'Send SOS'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

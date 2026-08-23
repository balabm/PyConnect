import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Manual occupancy update screen for PubClub and LuggageCloak vendors.
///
/// The partner adjusts the live occupancy percentage using a slider.
/// The backend translates the percentage to a current capacity count
/// against the venue's max capacity.
class OccupancyUpdateScreen extends ConsumerStatefulWidget {
  const OccupancyUpdateScreen({super.key, this.venueId});

  final String? venueId;

  @override
  ConsumerState<OccupancyUpdateScreen> createState() => _OccupancyUpdateScreenState();
}

class _OccupancyUpdateScreenState extends ConsumerState<OccupancyUpdateScreen> {
  final _venueIdController = TextEditingController();
  int _percentage = 50;
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.venueId != null) _venueIdController.text = widget.venueId!;
  }

  @override
  void dispose() {
    _venueIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_venueIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venue ID is required'), backgroundColor: AppTheme.danger));
      return;
    }
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.updateOccupancy(_venueIdController.text.trim(), _percentage);
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color get _percentageColor {
    if (_percentage > 85) return AppTheme.danger;
    if (_percentage > 60) return AppTheme.warning;
    return AppTheme.emerald;
  }

  String get _statusLabel {
    if (_percentage > 85) return 'Near Capacity';
    if (_percentage > 60) return 'Busy';
    if (_percentage > 30) return 'Moderate';
    return 'Quiet';
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Occupancy')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
                const SizedBox(height: 16),
                const Text('Occupancy Updated', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Live occupancy set to $_percentage%.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Update Occupancy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set the current live occupancy percentage. This is visible to consumers browsing venues in real-time.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: _venueIdController,
              decoration: const InputDecoration(
                labelText: 'Venue ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 32),
            // Big percentage display
            Center(
              child: Column(
                children: [
                  Text(
                    '$_percentage%',
                    style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: _percentageColor),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _percentageColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_statusLabel, style: TextStyle(color: _percentageColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Slider
            Slider(
              value: _percentage.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: _percentageColor,
              onChanged: (v) {
                AppHaptics.selection();
                setState(() => _percentage = v.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Empty', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                Text('Full', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 16),
            // Quick presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 25, 50, 75, 100].map((p) => ChoiceChip(
                label: Text('$p%'),
                selected: _percentage == p,
                onSelected: (_) {
                  AppHaptics.light();
                  setState(() => _percentage = p);
                },
              )).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.update),
                label: Text(_submitting ? 'Updating...' : 'Update Live Occupancy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

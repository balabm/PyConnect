import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Transit driver assignment screen for TaxiOperator vendors.
///
/// The partner enters the driver name and optional vehicle plate to
/// assign a driver to a transit trip. The backend validates ownership
/// and updates the trip record.
class AssignDriverScreen extends ConsumerStatefulWidget {
  const AssignDriverScreen({super.key, this.tripId});

  final String? tripId;

  @override
  ConsumerState<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends ConsumerState<AssignDriverScreen> {
  final _tripIdController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) _tripIdController.text = widget.tripId!;
  }

  @override
  void dispose() {
    _tripIdController.dispose();
    _driverNameController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.assignTransitDriver(
        _tripIdController.text.trim(),
        driverName: _driverNameController.text.trim(),
        vehiclePlate: _vehiclePlateController.text.trim().isNotEmpty
            ? _vehiclePlateController.text.trim()
            : null,
      );
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assign Driver')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.emerald, size: 64),
                const SizedBox(height: 16),
                const Text('Driver Assigned', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${_driverNameController.text} has been assigned to this trip.',
                    textAlign: TextAlign.center,
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
      appBar: AppBar(title: const Text('Assign Driver')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign a driver and vehicle to a transit trip. The driver will be responsible for completing this trip.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 24),
              Text('Trip ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tripIdController,
                decoration: const InputDecoration(
                  hintText: 'Paste or scan the trip ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Trip ID is required' : null,
              ),
              const SizedBox(height: 24),
              Text('Driver Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _driverNameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Suresh Kumar',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Driver name is required' : null,
              ),
              const SizedBox(height: 24),
              Text('Vehicle Plate (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vehiclePlateController,
                decoration: const InputDecoration(
                  hintText: 'e.g. PY 01 AB 1234',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_car),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.assignment_ind),
                  label: Text(_submitting ? 'Assigning...' : 'Assign Driver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

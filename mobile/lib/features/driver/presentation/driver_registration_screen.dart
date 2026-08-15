import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';

/// Driver self-registration screen.
///
/// Collects basic information (name, phone, vehicle type, plate) and
/// registers the driver via the backend API. After registration, the
/// driver is routed to the KYC upload screen.
class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  String _vehicleType = 'Bike';
  bool _isSubmitting = false;

  static const _vehicleTypes = ['Bike', 'Auto', 'Car'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_isValid) {
      AppToast.show(context, 'Please fill in all required fields',
          type: ToastType.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.medium();

    try {
      final api = ref.read(driverApiProvider);
      await api.registerDriver(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        vehiclePlate: _plateController.text.trim().isEmpty
            ? null
            : _plateController.text.trim(),
      );

      if (mounted) {
        AppHaptics.success();
        AppToast.show(context, 'Registration successful! Complete KYC to start.',
            type: ToastType.success);
        context.go('/kyc');
      }
    } on Exception catch (e) {
      if (mounted) {
        AppHaptics.error();
        AppToast.show(context, _friendlyError(e.toString()),
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('DioException') || raw.contains('Socket')) {
      return 'Could not reach the server. Please check your connection.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Captain'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppHaptics.light();
            context.go('/auth');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.two_wheeler,
                        color: AppTheme.emerald, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drive with PY Connect',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '0% commission · Instant payouts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'As per your driving license',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '10-digit mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
              items: _vehicleTypes.map((v) {
                return DropdownMenuItem(
                  value: v,
                  child: Text(v),
                );
              }).toList(),
              onChanged: (v) => setState(() => _vehicleType = v ?? 'Bike'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Plate (optional)',
                hintText: 'e.g. PY01AB1234',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.emerald),
                    )
                  : const Text('Register as Captain'),
            ),
          ],
        ),
      ),
    );
  }
}

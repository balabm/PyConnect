import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  String _vehicleType = 'Bike';
  bool _isSubmitting = false;

  static const _vehicleTypes = ['Bike', 'Auto', 'Car'];

  @override
  void initState() {
    super.initState();
    // Pre-fill the phone number from the authenticated session so the
    // driver record's phone matches the JWT phone. This prevents a
    // mismatch where the user could register with someone else's number.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(authControllerProvider).valueOrNull;
      if (session != null && session.phone.isNotEmpty && mounted) {
        _phoneController.text = session.phone;
        _nameController.text = session.name;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    AppHaptics.medium();

    try {
      final api = ref.read(driverApiProvider);
      final newToken = await api.registerDriver(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        vehiclePlate: _plateController.text.trim(),
        licenseNumber: _licenseController.text.trim(),
      );

      if (mounted) {
        // If the backend issued a fresh JWT with the Driver role, update
        // the local session so subsequent API calls carry the correct role.
        if (newToken != null && newToken.isNotEmpty) {
          await ref.read(authControllerProvider.notifier).refreshWithToken(newToken);
        }
        AppHaptics.success();
        AppToast.show(context, 'Registration successful! Complete KYC to start.',
            type: ToastType.success);
        // Force the router to re-fetch the driver profile so it no longer
        // treats the user as an unregistered driver and loops back here.
        ref.invalidate(driverProfileProvider);
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'As per your driving license',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Phone Number (from your login)',
                hintText: 'Authenticated phone number',
                prefixText: '+91 ',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                counterText: '',
                helperText: 'This is the phone number you verified with OTP.',
              ),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length != 10) {
                  return 'Enter a valid 10-digit phone number';
                }
                return null;
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
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
            TextFormField(
              controller: _plateController,
              decoration: const InputDecoration(
                labelText: 'Vehicle Plate Number',
                hintText: 'e.g. PY01AB1234',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your vehicle plate number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _licenseController,
              decoration: const InputDecoration(
                labelText: 'Driving License Number',
                hintText: 'e.g. PY01 20240001234',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your driving license number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Register as Captain'),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Login link for existing captains
            Center(
              child: TextButton(
                onPressed: () {
                  AppHaptics.light();
                  context.go('/auth');
                },
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'Already a captain? '),
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(
                          color: AppTheme.emerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

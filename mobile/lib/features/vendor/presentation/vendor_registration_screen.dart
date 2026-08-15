import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/vendor_onboarding_api.dart';

/// Partner self-registration screen.
///
/// Multi-step flow:
/// 1. Business details (name, category, phone, description)
/// 2. KYC documents (FSSAI, GST, PAN numbers + uploads)
/// 3. Bank details (account number, IFSC, account name)
/// 4. Success — pending admin approval
class VendorRegistrationScreen extends ConsumerStatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  ConsumerState<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState
    extends ConsumerState<VendorRegistrationScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Business details
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  // Step 2: KYC
  final _fssaiController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  File? _fssaiFile;
  File? _gstFile;
  File? _panFile;

  // Step 3: Bank
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();

  // Registration result
  String? _registeredVendorId;

  static const _categories = [
    ('Restaurant', 'Restaurant', Icons.restaurant_outlined),
    ('Cafe', 'Cafe', Icons.coffee_outlined),
    ('Pizzeria', 'Pizzeria', Icons.local_pizza_outlined),
    ('PubClub', 'Pub / Club', Icons.nightlife_outlined),
    ('ScooterRental', 'Scooter Rental', Icons.electric_scooter_outlined),
    ('Taxi', 'Taxi Operator', Icons.local_taxi_outlined),
    ('LuggageCloak', 'Luggage Cloak', Icons.luggage_outlined),
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _fssaiController.dispose();
    _gstController.dispose();
    _panController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  bool get _isStep1Valid =>
      _businessNameController.text.trim().isNotEmpty &&
      _selectedCategory != null &&
      _phoneController.text.trim().length >= 10;

  bool get _isStep2Valid =>
      _fssaiController.text.trim().isNotEmpty ||
      _gstController.text.trim().isNotEmpty ||
      _panController.text.trim().isNotEmpty;

  bool get _isStep3Valid =>
      _bankAccountController.text.trim().isNotEmpty &&
      _bankIfscController.text.trim().isNotEmpty &&
      _bankNameController.text.trim().isNotEmpty;

  Future<void> _pickFile(File? current, Function(File) onPicked) async {
    AppHaptics.light();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        title: 'Upload Document',
        subtitle: 'Choose how you want to add this document',
        child: Column(
          children: [
            _SourceOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(sheetContext);
                _doPick(ImageSourceChoice.camera, onPicked);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(sheetContext);
                _doPick(ImageSourceChoice.gallery, onPicked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doPick(
      ImageSourceChoice choice, Function(File) onPicked) async {
    final picker = ref.read(filePickerServiceProvider);
    final file = await picker.pickImage(choice);
    if (file != null) onPicked(file);
    AppHaptics.selection();
  }

  Future<void> _submitRegistration() async {
    if (!_isStep1Valid) {
      AppToast.show(context, 'Please fill in all business details',
          type: ToastType.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.medium();

    try {
      final api = ref.read(vendorOnboardingApiProvider);
      final result = await api.registerVendor(
        businessName: _businessNameController.text.trim(),
        category: _selectedCategory!,
        contactPhone: _phoneController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      _registeredVendorId = result.vendorId;
      AppHaptics.success();

      // Now upload KYC if any documents are provided
      if (_isStep2Valid || _isStep3Valid) {
        await api.uploadKyc(
          vendorId: result.vendorId,
          fssaiNumber: _fssaiController.text.trim().isEmpty
              ? null
              : _fssaiController.text.trim(),
          gstNumber:
              _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
          panNumber:
              _panController.text.trim().isEmpty ? null : _panController.text.trim(),
          fssaiDoc: _fssaiFile,
          gstDoc: _gstFile,
          panDoc: _panFile,
          bankAccountNumber: _bankAccountController.text.trim().isEmpty
              ? null
              : _bankAccountController.text.trim(),
          bankIfsc: _bankIfscController.text.trim().isEmpty
              ? null
              : _bankIfscController.text.trim(),
          bankAccountName: _bankNameController.text.trim().isEmpty
              ? null
              : _bankNameController.text.trim(),
        );
      }

      if (mounted) {
        setState(() {
          _currentStep = 3; // Success step
          _isSubmitting = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        AppHaptics.error();
        AppToast.show(context, _friendlyError(e.toString()),
            type: ToastType.error);
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already exists')) {
      return 'A vendor with this phone number already exists.';
    }
    if (raw.contains('DioException') || raw.contains('Socket')) {
      return 'Could not reach the server. Please check your connection.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Partner Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppHaptics.light();
            if (_currentStep > 0 && _currentStep < 3) {
              setState(() => _currentStep--);
            } else {
              context.go('/auth');
            }
          },
        ),
      ),
      body: _currentStep == 3
          ? _buildSuccessView()
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                } else {
                  context.go('/auth');
                }
              },
              controlsBuilder: (context, details) {
                final isLast = _currentStep == 2;
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : isLast
                                  ? _submitRegistration
                                  : details.onStepContinue,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(isLast ? 'Submit Registration' : 'Continue'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Business Details'),
                  subtitle: const Text('Tell us about your business'),
                  content: _buildBusinessStep(),
                  isActive: true,
                  state: _isStep1Valid
                      ? StepState.complete
                      : StepState.indexed,
                ),
                Step(
                  title: const Text('KYC Documents'),
                  subtitle: const Text('FSSAI, GST, PAN'),
                  content: _buildKycStep(),
                  isActive: true,
                  state: _isStep2Valid
                      ? StepState.complete
                      : StepState.indexed,
                ),
                Step(
                  title: const Text('Bank Details'),
                  subtitle: const Text('For payout transfers'),
                  content: _buildBankStep(),
                  isActive: true,
                  state: _isStep3Valid
                      ? StepState.complete
                      : StepState.indexed,
                ),
              ],
            ),
    );
  }

  Widget _buildBusinessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _businessNameController,
          decoration: const InputDecoration(
            labelText: 'Business Name',
            hintText: 'e.g. Fuoco Wood Fired Pizza',
            prefixIcon: Icon(Icons.store_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Business Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _categories.map((c) {
            return DropdownMenuItem(
              value: c.$1,
              child: Row(children: [
                Icon(c.$3, size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Text(c.$2, style: const TextStyle(color: Colors.white)),
              ]),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Contact Phone',
            hintText: '10-digit mobile number',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'Brief description of your business',
            prefixIcon: Icon(Icons.description_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildKycStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upload at least one identification document. Food businesses must provide FSSAI.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        _KycField(
          controller: _fssaiController,
          label: 'FSSAI License Number',
          hint: '14-digit FSSAI number',
          icon: Icons.restaurant_menu_outlined,
          file: _fssaiFile,
          onPickFile: (file) => setState(() => _fssaiFile = file),
          onPick: () => _pickFile(_fssaiFile, (f) => setState(() => _fssaiFile = f)),
        ),
        const SizedBox(height: AppSpacing.md),
        _KycField(
          controller: _gstController,
          label: 'GSTIN (optional)',
          hint: '15-digit GST number',
          icon: Icons.receipt_long_outlined,
          file: _gstFile,
          onPickFile: (file) => setState(() => _gstFile = file),
          onPick: () => _pickFile(_gstFile, (f) => setState(() => _gstFile = f)),
        ),
        const SizedBox(height: AppSpacing.md),
        _KycField(
          controller: _panController,
          label: 'PAN Number',
          hint: '10-digit PAN',
          icon: Icons.credit_card_outlined,
          file: _panFile,
          onPickFile: (file) => setState(() => _panFile = file),
          onPick: () => _pickFile(_panFile, (f) => setState(() => _panFile = f)),
        ),
      ],
    );
  }

  Widget _buildBankStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your bank account details for weekly payout transfers.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _bankNameController,
          decoration: const InputDecoration(
            labelText: 'Account Holder Name',
            hintText: 'Name on the bank account',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _bankAccountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Account Number',
            hintText: 'Bank account number',
            prefixIcon: Icon(Icons.account_balance_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _bankIfscController,
          decoration: const InputDecoration(
            labelText: 'IFSC Code',
            hintText: 'e.g. HDFC0001234',
            prefixIcon: Icon(Icons.code),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 64, color: AppTheme.success),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Registration Submitted!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your vendor ID is ${_registeredVendorId ?? ""}.\n\n'
              'Our team will review your application and approve it within 24-48 hours. '
              'You\'ll receive an SMS once approved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                AppHaptics.light();
                context.go('/auth');
              },
              icon: const Icon(Icons.login),
              label: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && !_isStep1Valid) {
      AppToast.show(context, 'Please fill in all business details',
          type: ToastType.warning);
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      AppHaptics.light();
    }
  }
}

class _KycField extends StatelessWidget {
  const _KycField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.file,
    required this.onPickFile,
    required this.onPick,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final File? file;
  final Function(File) onPickFile;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
          ),
        ),
        if (file != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Document selected: ${file!.path.split('/').last}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.success),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onPickFile(file!),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload Document'),
          ),
        ],
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.emerald),
            const SizedBox(width: 16),
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

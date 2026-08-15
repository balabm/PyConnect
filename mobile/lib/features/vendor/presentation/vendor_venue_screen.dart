import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

class VendorVenueScreen extends ConsumerStatefulWidget {
  const VendorVenueScreen({super.key});

  @override
  ConsumerState<VendorVenueScreen> createState() => _VendorVenueScreenState();
}

class _VendorVenueScreenState extends ConsumerState<VendorVenueScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openingTimeController = TextEditingController();
  final _closingTimeController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    super.dispose();
  }

  void _populateFields(VendorVenueDetail? venue) {
    if (venue == null || _initialized) return;
    _nameController.text = venue.name;
    _descriptionController.text = venue.description ?? '';
    _addressController.text = venue.address ?? '';
    _phoneController.text = venue.phone ?? '';
    _openingTimeController.text = venue.openingTime ?? '';
    _closingTimeController.text = venue.closingTime ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue name is required'), backgroundColor: AppTheme.coral),
      );
      return;
    }
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      await ref.read(venueDetailProvider.notifier).update(UpdateVenuePayload(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        openingTime: _openingTimeController.text.trim().isEmpty ? null : _openingTimeController.text.trim(),
        closingTime: _closingTimeController.text.trim().isEmpty ? null : _closingTimeController.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venue profile updated!'),
            backgroundColor: AppTheme.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.coral),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueAsync = ref.watch(venueDetailProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Venue Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: venueAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.coral),
              const SizedBox(height: 16),
              Text('Loading venue...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Could not load venue',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () => ref.read(venueDetailProvider.notifier).load(),
                ),
              ],
            ),
          ),
        ),
        data: (venue) {
          _populateFields(venue);

          if (venue == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_mall_directory, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text('No venue found',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('Contact admin to set up your venue profile.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(venue),
                const SizedBox(height: 16),
                _buildDarkField('Venue Name *', _nameController, 'e.g. The Hidden Bar'),
                const SizedBox(height: 12),
                _buildDarkField('Description', _descriptionController, 'Tell customers about your venue...', maxLines: 3),
                const SizedBox(height: 12),
                _buildDarkField('Address', _addressController, 'Full address'),
                const SizedBox(height: 12),
                _buildDarkField('Contact Phone', _phoneController, 'Phone number', keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDarkField('Opening Time', _openingTimeController, 'e.g. 18:00')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDarkField('Closing Time', _closingTimeController, 'e.g. 02:00')),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _saving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(VendorVenueDetail venue) {
    final isActive = venue.isActive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isActive ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.pause_circle,
            color: isActive ? AppTheme.success : AppTheme.danger,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Venue is Active' : 'Venue is Paused',
                  style: TextStyle(
                    color: isActive ? AppTheme.success : AppTheme.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isActive ? 'Accepting orders from customers' : 'Not visible to customers',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              venue.category,
              style: const TextStyle(color: AppTheme.coral, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.coral, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

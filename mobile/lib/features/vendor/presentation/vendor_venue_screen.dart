import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/config/service_area_config.dart';
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
  final _latController = TextEditingController(text: ServiceAreaConfig.defaultCenter.latitude.toString());
  final _lngController = TextEditingController(text: ServiceAreaConfig.defaultCenter.longitude.toString());
  final _capacityController = TextEditingController(text: '50');
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
    _latController.dispose();
    _lngController.dispose();
    _capacityController.dispose();
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

  Future<void> _createVenue() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue name is required'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final cap = int.tryParse(_capacityController.text.trim());
    if (lat == null || lng == null || cap == null || cap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid latitude, longitude, and capacity are required'), backgroundColor: AppTheme.danger),
      );
      return;
    }
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.createVenue(CreateVenuePayload(
        name: _nameController.text.trim(),
        category: 'Restaurant',
        latitude: lat,
        longitude: lng,
        maxCapacity: cap,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      ));
      await ref.read(venueDetailProvider.notifier).load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venue created!'), backgroundColor: AppTheme.emerald),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildCreateVenueForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.store_mall_directory, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Create Your Venue',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Set up your venue profile so customers can find you.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildDarkField('Venue Name *', _nameController, 'e.g. The Hidden Bar'),
          const SizedBox(height: 12),
          _buildDarkField('Description', _descriptionController, 'Tell customers about your venue...', maxLines: 3),
          const SizedBox(height: 12),
          _buildDarkField('Address', _addressController, 'Full address'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDarkField('Latitude', _latController, ServiceAreaConfig.defaultCenter.latitude.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _buildDarkField('Longitude', _lngController, ServiceAreaConfig.defaultCenter.longitude.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ],
          ),
          const SizedBox(height: 12),
          _buildDarkField('Max Capacity', _capacityController, '50', keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _createVenue,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _saving
                    ? SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : Text('Create Venue', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venue name is required'), backgroundColor: AppTheme.danger),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
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
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text('Venue Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: venueAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.emerald),
              const SizedBox(height: 16),
              Text('Loading venue...',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Could not load venue',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 18)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(),
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  onPressed: () => ref.read(venueDetailProvider.notifier).load(),
                ),
              ],
            ),
          ),
        ),
        data: (venue) {
          _populateFields(venue);

          if (venue == null) {
            return _buildCreateVenueForm();
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _saving
                          ? SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                          : Text('Save Changes', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onPrimary)),
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              venue.category,
              style: const TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w600),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.emerald, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';

/// Known Pondicherry area names mapped to approximate [latitude, longitude].
const _knownAreas = <String, List<double>>{
  'Auroville': [11.962, 79.833],
  'White Town': [11.931, 79.835],
  'Rock Beach': [11.938, 79.845],
  'City Center': [11.9356, 79.8301],
  'Lawspet': [11.941, 79.808],
  'Oulgaret': [11.949, 79.803],
};

/// Shift Preferences screen for the Driver (Captain) app.
///
/// Lets the captain enable destination mode (only receive rides heading
/// toward a chosen area) and toggle which service types they accept.
class DriverPreferencesScreen extends ConsumerStatefulWidget {
  const DriverPreferencesScreen({super.key});

  @override
  ConsumerState<DriverPreferencesScreen> createState() =>
      _DriverPreferencesScreenState();
}

class _DriverPreferencesScreenState
    extends ConsumerState<DriverPreferencesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Destination mode state
  bool _destinationModeEnabled = false;
  String? _destinationLabel;
  double? _destinationLatitude;
  double? _destinationLongitude;
  final _destinationController = TextEditingController();

  // Service toggle state
  bool _acceptFoodDelivery = true;
  bool _acceptRides = true;
  bool _acceptIntercity = false;
  bool _acceptLuggageTransport = false;
  bool _acceptEssentials = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(driverApiProvider);
      final prefs = await api.getPreferences();
      if (!mounted) return;
      setState(() {
        _destinationModeEnabled =
            prefs['destinationModeEnabled'] as bool? ?? false;
        _destinationLatitude =
            (prefs['destinationLatitude'] as num?)?.toDouble();
        _destinationLongitude =
            (prefs['destinationLongitude'] as num?)?.toDouble();
        _destinationLabel = prefs['destinationLabel'] as String?;
        _acceptFoodDelivery = prefs['acceptFoodDelivery'] as bool? ?? true;
        _acceptRides = prefs['acceptRides'] as bool? ?? true;
        _acceptIntercity = prefs['acceptIntercity'] as bool? ?? false;
        _acceptLuggageTransport =
            prefs['acceptLuggageTransport'] as bool? ?? false;
        _acceptEssentials = prefs['acceptEssentials'] as bool? ?? false;
        if (_destinationLabel != null) {
          _destinationController.text = _destinationLabel!;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _setDestination() async {
    final label = _destinationController.text.trim();
    if (label.isEmpty) {
      AppHaptics.warning();
      _showSnackbar('Please enter a destination label');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final coords = _lookupCoordinates(label);
      final latitude = coords[0];
      final longitude = coords[1];

      final api = ref.read(driverApiProvider);
      await api.setDestination(latitude, longitude, label);

      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _destinationModeEnabled = true;
        _destinationLabel = label;
        _destinationLatitude = latitude;
        _destinationLongitude = longitude;
        _isSaving = false;
      });

      final matched = _knownAreas.containsKey(label);
      _showSnackbar(
        matched
            ? 'Destination set: $label'
            : 'Area not found — defaulted to City Center. Destination set: $label',
      );
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() => _isSaving = false);
      _showSnackbar('Failed to set destination: $e');
    }
  }

  Future<void> _clearDestination() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.clearDestination();
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _destinationModeEnabled = false;
        _destinationLabel = null;
        _destinationLatitude = null;
        _destinationLongitude = null;
        _destinationController.clear();
        _isSaving = false;
      });
      _showSnackbar('Destination cleared');
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() => _isSaving = false);
      _showSnackbar('Failed to clear destination: $e');
    }
  }

  Future<void> _toggleServiceType({
    required String name,
    required bool? foodDelivery,
    required bool? rides,
    required bool? intercity,
    required bool? luggage,
    required bool? essentials,
    required bool newValue,
  }) async {
    AppHaptics.light();
    setState(() => _isSaving = true);
    try {
      final api = ref.read(driverApiProvider);
      await api.updateServiceToggles(
        foodDelivery: foodDelivery,
        rides: rides,
        intercity: intercity,
        luggage: luggage,
        essentials: essentials,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackbar('Updated: $name ${newValue ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      setState(() => _isSaving = false);
      _showSnackbar('Failed to update $name: $e');
    }
  }

  /// Looks up coordinates for a label, falling back to City Center.
  List<double> _lookupCoordinates(String label) {
    final exact = _knownAreas[label];
    if (exact != null) return exact;

    // Case-insensitive match
    for (final entry in _knownAreas.entries) {
      if (entry.key.toLowerCase() == label.toLowerCase()) {
        return entry.value;
      }
    }

    // Default to City Center
    return _knownAreas['City Center']!;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Preferences'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadPreferences,
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadPreferences,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildDestinationModeCard(),
              _buildServiceTypesCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withValues(alpha: 0.2),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildDestinationModeCard() {
    final hasDestination =
        _destinationModeEnabled && _destinationLabel != null;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: AppTheme.emerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Destination Mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Switch(
                  value: _destinationModeEnabled,
                  activeColor: AppTheme.emerald,
                  onChanged: hasDestination
                      ? null
                      : (value) {
                          AppHaptics.light();
                          setState(() {
                            _destinationModeEnabled = value;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Only receive rides heading toward your destination',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                  ),
            ),
            const SizedBox(height: 16),
            if (hasDestination) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Active: $_destinationLabel',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.emeraldDark,
                                    ),
                          ),
                          if (_destinationLatitude != null &&
                              _destinationLongitude != null)
                            Text(
                              '${_destinationLatitude!.toStringAsFixed(4)}, '
                              '${_destinationLongitude!.toStringAsFixed(4)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.slate,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination label',
                hintText: 'e.g. Auroville, White Town',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                enabled: !hasDestination,
              ),
            ),
            const SizedBox(height: 12),
            if (hasDestination)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _clearDestination,
                  icon: const Icon(Icons.close),
                  label: const Text('Clear Destination'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: BorderSide(color: AppTheme.danger),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _setDestination,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Set Destination'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypesCard() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: AppTheme.info),
                const SizedBox(width: 8),
                Text(
                  'Service Types',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which ride types you want to accept',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                  ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: Icon(Icons.restaurant_outlined, color: AppTheme.gold),
              title: const Text('Food Delivery'),
              value: _acceptFoodDelivery,
              activeColor: AppTheme.emerald,
              onChanged: (value) {
                setState(() => _acceptFoodDelivery = value);
                _toggleServiceType(
                  name: 'Food Delivery',
                  foodDelivery: value,
                  rides: null,
                  intercity: null,
                  luggage: null,
                  essentials: null,
                  newValue: value,
                );
              },
            ),
            SwitchListTile(
              secondary: Icon(Icons.two_wheeler_outlined, color: AppTheme.emerald),
              title: const Text('Rides'),
              value: _acceptRides,
              activeColor: AppTheme.emerald,
              onChanged: (value) {
                setState(() => _acceptRides = value);
                _toggleServiceType(
                  name: 'Rides',
                  foodDelivery: null,
                  rides: value,
                  intercity: null,
                  luggage: null,
                  essentials: null,
                  newValue: value,
                );
              },
            ),
            SwitchListTile(
              secondary: Icon(Icons.airport_shuttle_outlined, color: AppTheme.info),
              title: const Text('Intercity Cabs'),
              value: _acceptIntercity,
              activeColor: AppTheme.emerald,
              onChanged: (value) {
                setState(() => _acceptIntercity = value);
                _toggleServiceType(
                  name: 'Intercity Cabs',
                  foodDelivery: null,
                  rides: null,
                  intercity: value,
                  luggage: null,
                  essentials: null,
                  newValue: value,
                );
              },
            ),
            SwitchListTile(
              secondary: Icon(Icons.luggage_outlined, color: AppTheme.warning),
              title: const Text('Luggage Transport'),
              value: _acceptLuggageTransport,
              activeColor: AppTheme.emerald,
              onChanged: (value) {
                setState(() => _acceptLuggageTransport = value);
                _toggleServiceType(
                  name: 'Luggage Transport',
                  foodDelivery: null,
                  rides: null,
                  intercity: null,
                  luggage: value,
                  essentials: null,
                  newValue: value,
                );
              },
            ),
            SwitchListTile(
              secondary: Icon(Icons.shopping_bag_outlined, color: AppTheme.danger),
              title: const Text('Essentials'),
              value: _acceptEssentials,
              activeColor: AppTheme.emerald,
              onChanged: (value) {
                setState(() => _acceptEssentials = value);
                _toggleServiceType(
                  name: 'Essentials',
                  foodDelivery: null,
                  rides: null,
                  intercity: null,
                  luggage: null,
                  essentials: value,
                  newValue: value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

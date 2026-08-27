import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';

/// Garage screen for the Driver (Captain) app.
///
/// Drivers manage their registered vehicles here: view status, add new
/// vehicles, set a vehicle as active, and delete inactive ones.
class GarageScreen extends ConsumerStatefulWidget {
  const GarageScreen({super.key});

  @override
  ConsumerState<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends ConsumerState<GarageScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final api = ref.read(driverApiProvider);
      final vehicles = await api.getVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      AppHaptics.error();
    }
  }

  Future<void> _onRefresh() async {
    AppHaptics.light();
    await _loadVehicles();
  }

  Future<void> _activateVehicle(String vehicleId) async {
    AppHaptics.medium();
    try {
      final api = ref.read(driverApiProvider);
      await api.activateVehicle(vehicleId);
      AppHaptics.success();
      if (!mounted) return;
      _showSnack('Vehicle set as active', AppTheme.emerald);
      await _loadVehicles();
    } catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      _showSnack('Failed to activate vehicle', AppTheme.danger);
    }
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    AppHaptics.medium();
    try {
      final api = ref.read(driverApiProvider);
      await api.deleteVehicle(vehicleId);
      AppHaptics.success();
      if (!mounted) return;
      _showSnack('Vehicle removed', AppTheme.emerald);
      await _loadVehicles();
    } catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      _showSnack('Failed to delete vehicle', AppTheme.danger);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddVehicleSheet() {
    AppHaptics.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddVehicleSheet(
        onSubmit: ({required vehicleType, required registrationNumber, color, model}) async {
          try {
            final api = ref.read(driverApiProvider);
            await api.addVehicle(
              vehicleType: vehicleType,
              registrationNumber: registrationNumber,
              color: color,
              model: model,
            );
            AppHaptics.success();
            if (!mounted) return;
            _showSnack('Vehicle added', AppTheme.emerald);
            await _loadVehicles();
          } catch (e) {
            AppHaptics.error();
            if (!mounted) return;
            _showSnack('Failed to add vehicle', AppTheme.danger);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Garage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadVehicles,
      );
    }
    if (_vehicles.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No vehicles yet',
        subtitle: 'Add your first vehicle to start accepting rides.',
        actionLabel: 'Add Vehicle',
        onAction: _showAddVehicleSheet,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return _VehicleCard(
          vehicle: vehicle,
          onActivate: () => _activateVehicle(vehicle['id'].toString()),
          onDelete: () => _deleteVehicle(vehicle['id'].toString()),
        );
      },
    );
  }
}

/// A single vehicle card with status badge and action buttons.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onActivate,
    required this.onDelete,
  });

  final Map<String, dynamic> vehicle;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  IconData get _vehicleIcon {
    final type = vehicle['vehicleType'];
    final typeStr = type is num ? type.toString() : (type as String? ?? '');
    switch (typeStr.toLowerCase()) {
      case '1':
      case 'bike':
        return Icons.two_wheeler;
      case '2':
      case 'auto':
        return Icons.local_taxi;
      case '3':
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  String get _vehicleTypeLabel {
    final type = vehicle['vehicleType'];
    final typeStr = type is num ? type.toString() : (type as String? ?? '');
    switch (typeStr.toLowerCase()) {
      case '1':
      case 'bike':
        return 'Bike';
      case '2':
      case 'auto':
        return 'Auto';
      case '3':
      case 'car':
        return 'Car';
      default:
        return 'Vehicle';
    }
  }

  ({String label, Color color}) get _status {
    final isApproved = (vehicle['isApproved'] as bool?) ?? false;
    final isActive = (vehicle['isActive'] as bool?) ?? false;
    if (isActive) return (label: 'Active', color: AppTheme.emerald);
    if (isApproved) return (label: 'Inactive', color: AppTheme.slate);
    return (label: 'Pending Approval', color: AppTheme.warning);
  }

  @override
  Widget build(BuildContext context) {
    final registrationNumber =
        (vehicle['registrationNumber'] as String?) ?? '—';
    final model = vehicle['model'] as String?;
    final colorName = vehicle['color'] as String?;
    final isApproved = (vehicle['isApproved'] as bool?) ?? false;
    final isActive = (vehicle['isActive'] as bool?) ?? false;
    final reviewNotes = vehicle['reviewNotes'] as String?;
    final status = _status;

    final subtitle = [
      if (model != null && model.isNotEmpty) model,
      if (colorName != null && colorName.isNotEmpty) colorName,
    ].join(' • ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_vehicleIcon, color: AppTheme.emerald, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registrationNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      Text(
                        _vehicleTypeLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(label: status.label, color: status.color),
            ],
          ),
          if (!isApproved && reviewNotes != null && reviewNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      reviewNotes,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.warning,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isApproved && !isActive || !isActive) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (isApproved && !isActive)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onActivate,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Set Active'),
                    ),
                  ),
                if (isApproved && !isActive) const SizedBox(width: AppSpacing.sm),
                if (!isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.4)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pill-shaped status badge.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bottom sheet form for adding a new vehicle.
class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet({required this.onSubmit});

  final Future<void> Function({
    required String vehicleType,
    required String registrationNumber,
    String? color,
    String? model,
  }) onSubmit;

  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  int _vehicleType = 3; // Default to Car
  final _regController = TextEditingController();
  final _colorController = TextEditingController();
  final _modelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _regController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  String _typeLabel(int type) {
    switch (type) {
      case 1:
        return 'Bike';
      case 2:
        return 'Auto';
      case 3:
        return 'Car';
      default:
        return 'Car';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppHaptics.error();
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit(
      vehicleType: _typeLabel(_vehicleType),
      registrationNumber: _regController.text.trim().toUpperCase(),
      color: _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim(),
      model: _modelController.text.trim().isEmpty
          ? null
          : _modelController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppTheme.slate.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Text(
              'Add Vehicle',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Vehicle Type',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.two_wheeler),
                  label: Text('Bike'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: Icon(Icons.local_taxi),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: 3,
                  icon: Icon(Icons.directions_car),
                  label: Text('Car'),
                ),
              ],
              selected: {_vehicleType},
              onSelectionChanged: (selection) {
                AppHaptics.light();
                setState(() => _vehicleType = selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _regController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
                hintText: 'PY 01 AB 1234',
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Registration number is required';
                }
                return null;
              },
              onChanged: (value) {
                final upper = value.toUpperCase();
                if (upper != value) {
                  _regController.value = TextEditingValue(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _colorController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Color (optional)',
                hintText: 'Black',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _modelController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Model (optional)',
                hintText: 'Honda Activa 6G',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}

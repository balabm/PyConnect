import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/service_area_config.dart';
import '../../../core/design/map_tile_config.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/address_provider.dart';
import 'widgets/address_search_delegate.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _pin = ServiceAreaConfig.defaultCenter;
  bool _showFallback = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  Future<void> _requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition();
        _pin = LatLng(position.latitude, position.longitude);
        _showFallback = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_pin, 16);
        });
      } catch (_) {
        // Fall back to default Pondicherry center.
        _showFallback = false;
      }
    }
    setState(() => _loading = false);
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      setState(() => _pin = event.camera.center);
    }
  }

  void _onSearchResult(LatLng latLng) {
    setState(() {
      _pin = latLng;
      _showFallback = false;
    });
    _mapController.move(latLng, 16);
  }

  void _openSearch() {
    showSearch<LatLng?>(
      context: context,
      delegate: AddressSearchDelegate(onSelected: _onSearchResult),
    );
  }

  void _openSettings() => openAppSettings();

  void _openAddressForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddressForm(
        pin: _pin,
        onSave: (draft) async {
          try {
            await ref.read(currentLocationProvider.notifier).saveAddress(draft);
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Address saved.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text('Could not save address: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showFallback) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set your location')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'We need your location to show nearby drivers and restaurants.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _openSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search Manually'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin your location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
            tooltip: 'Search address',
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _pin,
          initialZoom: 16,
          onMapEvent: _onMapEvent,
        ),
        children: [
          MapTileConfig.forTheme(context),
          MarkerLayer(
            markers: [
              Marker(
                point: _pin,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddressForm,
        icon: const Icon(Icons.check),
        label: const Text('Confirm Pin'),
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({required this.pin, required this.onSave});

  final LatLng pin;
  final ValueChanged<Address> onSave;

  @override
  __AddressFormState createState() => __AddressFormState();
}

class __AddressFormState extends State<_AddressForm> {
  final _doorFlatController = TextEditingController();
  final _landmarkController = TextEditingController();
  String _tag = 'Home';

  final _tags = ['Home', 'Work', 'Other'];

  @override
  void dispose() {
    _doorFlatController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _save() {
    final address = Address(
      doorFlat: _doorFlatController.text.trim().isEmpty
          ? null
          : _doorFlatController.text.trim(),
      landmark: _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim(),
      tag: _tag,
      latitude: widget.pin.latitude,
      longitude: widget.pin.longitude,
      formattedAddress: 'Pinned location (${widget.pin.latitude.toStringAsFixed(5)}, ${widget.pin.longitude.toStringAsFixed(5)})',
    );
    widget.onSave(address);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Save address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _doorFlatController,
                decoration: const InputDecoration(
                  labelText: 'Door/Flat No.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: 'Landmark',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tag'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _tags.map((tag) {
                  final selected = _tag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => setState(() => _tag = tag),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save Address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

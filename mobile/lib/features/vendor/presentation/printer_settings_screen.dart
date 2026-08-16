import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';

/// Printer settings screen — scan, select, connect, and test a Bluetooth
/// thermal printer. The selected printer's MAC address is persisted to
/// [SharedPreferences] via [ThermalPrinterService] for auto-reconnect.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _testing = false;
  String? _savedAddress;
  String? _savedName;
  String? _selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _checkConnection();
  }

  Future<void> _loadSavedPrinter() async {
    final service = ref.read(thermalPrinterProvider);
    final address = await service.getSavedPrinterAddress();
    final name = await service.getSavedPrinterName();
    if (mounted) {
      setState(() {
        _savedAddress = address;
        _savedName = name;
        _selectedAddress = address;
      });
    }
  }

  Future<void> _checkConnection() async {
    final service = ref.read(thermalPrinterProvider);
    final connected = await service.isConnected();
    if (mounted) setState(() => _connected = connected);
  }

  Future<void> _scan() async {
    AppHaptics.light();
    setState(() {
      _scanning = true;
      _devices = [];
    });
    try {
      final service = ref.read(thermalPrinterProvider);
      final devices = await service.scanPrinters();
      if (mounted) {
        setState(() {
          _devices = devices;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    AppHaptics.medium();
    setState(() => _connecting = true);
    try {
      final service = ref.read(thermalPrinterProvider);
      final success = await service.connect(device);
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = success;
          _selectedAddress = device.address;
          _savedAddress = device.address;
          _savedName = device.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Connected to ${device.name ?? device.address}'
                : 'Failed to connect'),
            backgroundColor: success ? AppTheme.emerald : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    AppHaptics.light();
    final service = ref.read(thermalPrinterProvider);
    await service.disconnect();
    if (mounted) {
      setState(() => _connected = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    AppHaptics.medium();
    setState(() => _testing = true);
    try {
      final service = ref.read(thermalPrinterProvider);
      final success = await service.printTestTicket();
      if (mounted) {
        setState(() => _testing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Test print sent successfully'
                : 'Print failed — is the printer connected?'),
            backgroundColor: success ? AppTheme.emerald : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _testing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Printer Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Scan button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Printers'),
                onPressed: _scanning ? null : _scan,
              ),
            ),
            const SizedBox(height: 16),

            // Saved printer info
            if (_savedAddress != null && _savedAddress!.isNotEmpty) ...[
              _buildSavedPrinterCard(),
              const SizedBox(height: 16),
            ],

            // Discovered devices list
            if (_devices.isNotEmpty) ...[
              const Text(
                'Discovered Printers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._devices.map((device) => _buildDeviceTile(device)),
            ] else if (!_scanning) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.print,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(
                        'No printers found.\nTap "Scan for Printers" to search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Test print button
            if (_connected) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.emerald.withValues(alpha: 0.15),
                    foregroundColor: AppTheme.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.emerald,
                          ),
                        )
                      : const Icon(Icons.receipt),
                  label: const Text('Print Test Ticket'),
                  onPressed: _testing ? null : _testPrint,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                  ),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect Printer'),
                  onPressed: _disconnect,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _connected ? AppTheme.success : AppTheme.warning;
    final label = _connected ? 'Connected' : 'Not Connected';
    final icon = _connected ? Icons.check_circle : Icons.print_disabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer Status',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_connecting)
            const SizedBox(
              width: 24,
              height: 24,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedPrinterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark, color: AppTheme.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Printer',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _savedName ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _savedAddress ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device) {
    final isSelected = _selectedAddress == device.address;
    final isSaved = _savedAddress == device.address;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.print,
          color: isSelected ? AppTheme.emerald : Colors.white.withValues(alpha: 0.5),
        ),
        title: Text(
          device.name ?? 'Unknown Device',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          device.address ?? '',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSaved)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.bookmark, color: AppTheme.info, size: 18),
              ),
            if (_connecting && isSelected)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppTheme.emerald.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.08),
                  foregroundColor: isSelected ? AppTheme.emerald : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                ),
                onPressed: () => _connectToDevice(device),
                child: const Text('Connect'),
              ),
          ],
        ),
      ),
    );
  }
}

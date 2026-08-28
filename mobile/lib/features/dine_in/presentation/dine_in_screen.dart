import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/dine_in_api.dart';

final dineInApiProvider = Provider<DineInApi>((ref) {
  return DineInApi(ref.watch(apiClientProvider));
});

/// Dine-in QR ordering screen.
/// Customers scan a QR code at their table to open a session,
/// then order from the menu and pay via UPI.
class DineInScreen extends ConsumerStatefulWidget {
  const DineInScreen({super.key});

  @override
  ConsumerState<DineInScreen> createState() => _DineInScreenState();
}

class _DineInScreenState extends ConsumerState<DineInScreen> {
  late final MobileScannerController _cameraController;
  bool _scanning = true;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || !_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!;
    _processQrCode(rawValue);
  }

  Future<void> _processQrCode(String qrData) async {
    setState(() {
      _processing = true;
      _scanning = false;
      _error = null;
    });
    AppHaptics.light();

    try {
      // Expected QR format: https://pyconnect.run.place/dine-in?venueId=...&vendorId=...&tableId=...
      // Or JSON: {"venueId":"...","vendorId":"...","tableId":1}
      String? venueId;
      String? vendorId;
      int? tableId;

      if (qrData.startsWith('http')) {
        final uri = Uri.parse(qrData);
        venueId = uri.queryParameters['venueId'];
        vendorId = uri.queryParameters['vendorId'];
        tableId = int.tryParse(uri.queryParameters['tableId'] ?? '');
      } else if (qrData.startsWith('{')) {
        // Try JSON parse (simple approach)
        final venueMatch = RegExp(r'"venueId"\s*:\s*"([^"]+)"').firstMatch(qrData);
        final vendorMatch = RegExp(r'"vendorId"\s*:\s*"([^"]+)"').firstMatch(qrData);
        final tableMatch = RegExp(r'"tableId"\s*:\s*(\d+)').firstMatch(qrData);
        venueId = venueMatch?.group(1);
        vendorId = vendorMatch?.group(1);
        tableId = tableMatch != null ? int.tryParse(tableMatch.group(1)!) : null;
      }

      if (venueId == null || vendorId == null || tableId == null) {
        setState(() {
          _error = 'Invalid table QR code. Make sure you\'re scanning the QR on your table.';
          _processing = false;
          _scanning = true;
        });
        return;
      }

      final session = await ref.read(dineInApiProvider).scanTable(
            venueId: venueId,
            vendorId: vendorId,
            tableId: tableId,
          );

      if (!mounted) return;

      // Navigate to the food menu for this vendor with dine-in context.
      // The session ID is passed as a query param so the food screen can
      // associate the order with the dine-in session.
      context.go('/food/vendor/$vendorId?name=Dine-In&deliveryFee=0&dineIn=${session.sessionId}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not scan table: $e';
          _processing = false;
          _scanning = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dine In')),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.emerald.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.emerald, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan the QR code on your table to view the menu and order directly.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Camera view
          Expanded(
            child: Stack(
              children: [
                if (_scanning)
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: _onDetect,
                  ),
                // Scanner overlay
                if (_scanning) _buildScannerOverlay(),
                if (_processing) _buildProcessingOverlay(),
                if (_error != null) _buildErrorOverlay(),
              ],
            ),
          ),
          // Manual entry fallback
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showManualEntrySheet(context),
              icon: const Icon(Icons.edit),
              label: const Text('Enter table code manually'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.4),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: CircularProgressIndicator(color: AppTheme.emerald),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () => setState(() => _error = null),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntrySheet(BuildContext context) {
    final venueCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final tableCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manual Table Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Enter the venue ID, vendor ID, and table number from your table card.',
                style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: venueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Venue ID',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: vendorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Vendor ID',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: tableCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Table number',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(sheetContext);
                    _processQrCode(
                      '{"venueId":"${venueCtrl.text.trim()}","vendorId":"${vendorCtrl.text.trim()}","tableId":${tableCtrl.text.trim()}}',
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.emerald,
                  ),
                  child: const Text('Open Menu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

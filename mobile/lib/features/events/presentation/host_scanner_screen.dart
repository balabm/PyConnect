import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../data/p2p_event_api.dart';

/// Host scanner screen — allows event hosts to scan guest QR tickets.
///
/// Only accessible to the authenticated host of an active event.
/// Validates tickets against the backend and marks them as checked in.
class HostScannerScreen extends ConsumerStatefulWidget {
  const HostScannerScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<HostScannerScreen> createState() => _HostScannerScreenState();
}

class _HostScannerScreenState extends ConsumerState<HostScannerScreen> {
  bool _scanning = true;
  TicketValidationResponseModel? _lastResult;
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _processing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final payload = barcodes.first.rawValue;
    if (payload == null || payload.isEmpty) return;

    // Pause scanning while processing
    setState(() {
      _scanning = false;
      _processing = true;
    });

    AppHaptics.light();

    try {
      final result = await ref.read(p2pEventApiProvider).validateTicket(
            eventId: widget.eventId,
            qrPayload: payload,
          );

      if (mounted) {
        setState(() {
          _lastResult = result;
          _processing = false;
        });

        if (result.isValid) {
          AppHaptics.success();
        } else {
          AppHaptics.error();
        }

        // Show result dialog
        _showResultDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showResultDialog(TicketValidationResponseModel result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          result.isValid ? Icons.check_circle : Icons.cancel,
          color: result.isValid ? AppTheme.emerald : AppTheme.danger,
          size: 48,
        ),
        title: Text(result.isValid ? 'Welcome!' : result.isDuplicate ? 'Duplicate' : 'Invalid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (result.isValid) ...[
              const SizedBox(height: 8),
              Text(
                result.buyerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
            if (result.isDuplicate && result.previousScanAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Previously scanned at: ${result.previousScanAt}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeScanning();
            },
            child: const Text('Scan Next'),
          ),
        ],
      ),
    );
  }

  void _resumeScanning() {
    setState(() {
      _scanning = true;
      _lastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Guests'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
            ),
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _processing ? Colors.grey : AppTheme.emerald,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Status indicator
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _processing
                      ? 'Validating...'
                      : _scanning
                          ? 'Point at QR ticket'
                          : 'Paused',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          // Bottom info
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan each guest\'s QR ticket as they arrive. Duplicate scans will be rejected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

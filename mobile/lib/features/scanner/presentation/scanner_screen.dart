import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/scanner_api.dart';
import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../vendor/application/vendor_providers.dart';

enum ScannerState { idle, scanning, success, error, duplicate, networkError, permissionDenied }

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _cameraController;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  ScannerState _state = ScannerState.idle;
  TicketValidationResult? _result;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _lastScanned;
  DateTime _lastScanAt = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return;

    final result = await Permission.camera.request();
    if (!result.isGranted && mounted) {
      setState(() => _state = ScannerState.permissionDenied);
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_state != ScannerState.idle) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final payload = barcodes.first.rawValue;
    if (payload == null || payload.isEmpty) return;

    _onQrCode(payload);
  }

  void _onQrCode(String code) {
    final now = DateTime.now();
    if (code == _lastScanned &&
        now.difference(_lastScanAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastScanned = code;
    _lastScanAt = now;
    setState(() => _state = ScannerState.scanning);
    _cameraController.stop();
    unawaited(_validateTicket(code));
  }

  Future<void> _validateTicket(String payload) async {
    try {
      final result = await ref.read(scannerApiProvider).validateTicket(payload);
      _retryCount = 0;

      if (result.isValid) {
        setState(() {
          _state = ScannerState.success;
          _result = result;
        });
        _animationController.forward();
        AppHaptics.heavy();
        _playSuccessSound();
      } else if (result.isDuplicate) {
        setState(() {
          _state = ScannerState.duplicate;
          _result = result;
        });
        _animationController.forward();
        _playErrorSound();
        // Heavy double-vibration to flag fraud/duplicate scans distinctly.
        AppHaptics.heavy();
        Future.delayed(const Duration(milliseconds: 250), AppHaptics.heavy);
      } else {
        setState(() {
          _state = ScannerState.error;
          _result = result;
        });
        _animationController.forward();
        AppHaptics.error();
        _playErrorSound();
      }
    } catch (e) {
      _retryCount++;
      if (_retryCount >= _maxRetries) {
        setState(() => _state = ScannerState.networkError);
        AppHaptics.error();
        _playErrorSound();
      } else {
        await Future.delayed(Duration(seconds: 1 * _retryCount));
        await _validateTicket(payload);
      }
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _resumeScanner() {
    AppHaptics.light();
    _cameraController.start();
    setState(() {
      _state = ScannerState.idle;
      _result = null;
      _retryCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraView(),
          if (_state == ScannerState.idle) _buildScanOverlay(),
          if (_state == ScannerState.scanning) _buildScanningOverlay(),
          if (_state == ScannerState.success) _buildSuccessOverlay(),
          if (_state == ScannerState.duplicate) _buildDuplicateOverlay(),
          if (_state == ScannerState.error) _buildErrorOverlay(),
          if (_state == ScannerState.networkError) _buildNetworkErrorOverlay(),
          if (_state == ScannerState.permissionDenied) _buildPermissionDeniedOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: _cameraController,
      onDetect: _onDetect,
    );
  }

  Widget _buildScanOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: const _ScannerOverlayPainter(
                  cutoutSize: Size(250, 250),
                  borderRadius: 20,
                  overlayColor: Colors.black54,
                ),
              ),
            ),
            // Scan frame with corner accents
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.emeraldLight, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner accents
                    Positioned(
                      top: -2, left: -2,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(width: 4, color: AppTheme.emeraldLight),
                            left: BorderSide(width: 4, color: AppTheme.emeraldLight),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2, right: -2,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(width: 4, color: AppTheme.emeraldLight),
                            right: BorderSide(width: 4, color: AppTheme.emeraldLight),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2, left: -2,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(width: 4, color: AppTheme.emeraldLight),
                            left: BorderSide(width: 4, color: AppTheme.emeraldLight),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2, right: -2,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(width: 4, color: AppTheme.emeraldLight),
                            right: BorderSide(width: 4, color: AppTheme.emeraldLight),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                'Align QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.emerald, AppTheme.emeraldDark],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'VALID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _friendlyPassType(_result?.serviceType ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Customer: ${_result?.userName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Cover charge credit info — shows the bouncer and waitstaff
                // how many guests are covered and how much credit is available.
                if (_result?.guestCount != null && _result!.guestCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Valid Entry: ${_result!.guestCount} Guests. '
                      'Cover Charge Paid: ₹${_result!.coverChargeAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (_result?.message != null && _result!.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _result!.message,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _resumeScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('[ Tap to Scan Next ]'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a backend service type string to a friendly pass type label.
  static String _friendlyPassType(String serviceType) {
    final lower = serviceType.toLowerCase();
    if (lower.contains('pub') || lower.contains('entry') || lower.contains('nightlife')) {
      return 'Pub Entry Pass';
    }
    if (lower.contains('homestay') || lower.contains('stay') || lower.contains('hotel')) {
      return 'Homestay Check-In';
    }
    if (lower.contains('cloak') || lower.contains('luggage') || lower.contains('bag')) {
      return 'Cloakroom Bag Drop';
    }
    if (lower.contains('scooter') || lower.contains('rental') || lower.contains('bike')) {
      return 'Scooter Handover';
    }
    if (serviceType.isEmpty) return 'Valid Pass';
    return serviceType;
  }

  Widget _buildDuplicateOverlay() {
    final scanTime = _result?.previousScanAt ?? '';
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF0000), Color(0xFF8B0000)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'INVALID',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                if (scanTime.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Scanned at $scanTime',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _result?.message.isNotEmpty == true
                      ? _result!.message
                      : 'This ticket has already been scanned.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8B0000),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _resumeScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('[ Tap to Scan Next ]'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.warning, Color(0xFFFBBF24)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  _result?.message.isNotEmpty == true
                      ? _result!.message
                      : 'INVALID OR ALREADY USED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _resumeScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('[ Tap to Scan Next ]'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorOverlay() {
    return Container(
      color: AppTheme.warning,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Network Error: Retrying...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _resumeScanner,
                child: const Text('Retry Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedOverlay() {
    return Container(
      color: Colors.red.shade900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please grant camera access to scan tickets.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({
    required this.cutoutSize,
    required this.borderRadius,
    required this.overlayColor,
  });

  final Size cutoutSize;
  final double borderRadius;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final center = Offset(size.width / 2, size.height / 2);
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: cutoutSize.width,
            height: cutoutSize.height,
          ),
          Radius.circular(borderRadius),
        ),
      );
    final overlay = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(overlay, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.cutoutSize != cutoutSize ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.overlayColor != overlayColor;
}

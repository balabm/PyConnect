import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/scanner_api.dart';
import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../vendor/application/vendor_providers.dart';

enum ScannerState { idle, scanning, success, error, networkError, permissionDenied }

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
  StreamSubscription<Object?>? _subscription;

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
    _subscription = _cameraController.barcodes.listen(_onDetect);
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
    _subscription?.cancel();
    _cameraController.dispose();
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_state != ScannerState.idle) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final payload = barcodes.first.rawValue;
    if (payload == null || payload.isEmpty) return;

    setState(() => _state = ScannerState.scanning);
    await _validateTicket(payload);
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
        AppHaptics.success();
        _playSuccessSound();
      } else {
        setState(() {
          _state = ScannerState.error;
          _result = result;
        });
        _animationController.forward();
        AppHaptics.error();
        _playErrorSound();
      }

      _resetAfterDelay();
    } catch (e) {
      _retryCount++;
      if (_retryCount >= _maxRetries) {
        setState(() => _state = ScannerState.networkError);
        AppHaptics.error();
        _playErrorSound();
        _resetAfterDelay();
      } else {
        await Future.delayed(Duration(seconds: 1 * _retryCount));
        await _validateTicket(payload);
      }
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (_) {}
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (_) {}
  }

  void _resetAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _state = ScannerState.idle;
          _result = null;
        });
        _animationController.reset();
      }
    });
  }

  void _manualRetry() {
    AppHaptics.light();
    setState(() {
      _state = ScannerState.idle;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Scan frame with gradient border
            Container(
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Scan Ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
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
                  '${_result?.serviceType} - ${_result?.userName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
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
            colors: [AppTheme.coral, AppTheme.coralLight],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkErrorOverlay() {
    return Container(
      color: Colors.amber.shade700,
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
                onPressed: _manualRetry,
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

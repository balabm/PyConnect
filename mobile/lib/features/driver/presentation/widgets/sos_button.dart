import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/animations/haptic.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/driver_providers.dart';

/// A persistent floating SOS (panic) button for the Driver (Captain) app.
///
/// Renders a red shield icon that requires a 3-second long-press to trigger,
/// preventing accidental activation. While pressed, a circular progress
/// indicator fills around the button. On successful trigger, the widget
/// calls the backend SOS endpoint and dials India's emergency number (112).
///
/// Designed to be placed inside a [Stack] over the live map / home screen.
class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key});

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);
  static const _buttonDiameter = 64.0;

  late final AnimationController _controller;
  bool _isSending = false;
  bool _sosSent = false;

  /// Current status text shown beneath the button.
  String get _statusText {
    if (_sosSent) return 'SOS Sent!';
    if (_isSending) return 'Sending SOS...';
    if (_controller.isAnimating) return 'Hold for SOS';
    return 'Hold for SOS';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _holdDuration,
    );
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isSending && !_sosSent) {
      _triggerSos();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  // ── Gesture handlers ──────────────────────────────────────────────

  void _onPressStart() {
    if (_isSending || _sosSent) return;
    AppHaptics.heavy();
    _controller.forward();
    if (mounted) setState(() {});
  }

  void _onPressEnd() {
    if (_isSending || _sosSent) return;
    // Released before the 3-second hold completed — cancel and reset.
    _controller.reverse();
  }

  // ── SOS trigger ───────────────────────────────────────────────────

  Future<void> _triggerSos() async {
    AppHaptics.error();

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    final activeTask = ref.read(activeTaskProvider);
    final rideId = activeTask?.id;

    // Always attempt to dial emergency services (112 — India).
    await _dialEmergency();

    if (rideId == null) {
      // No active ride — notify and skip backend call.
      if (mounted) {
        _showSnackBar('SOS: No active ride. Calling emergency services.');
        setState(() {
          _isSending = false;
          _sosSent = true;
        });
      }
      _resetAfterDelay();
      return;
    }

    try {
      final api = ref.read(driverApiProvider);
      // Placeholder coordinates (0, 0) — the backend resolves the driver's
      // live location from the SignalR connection.
      await api.triggerSos(rideId, 0, 0);

      if (mounted) {
        _showSnackBar('SOS triggered. Emergency services notified.');
        setState(() {
          _isSending = false;
          _sosSent = true;
        });
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('SOS failed to send. Calling emergency services.');
        setState(() {
          _isSending = false;
          _sosSent = true;
        });
      }
    }

    _resetAfterDelay();
  }

  Future<void> _dialEmergency() async {
    try {
      final uri = Uri.parse('tel:112');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {
      // Silently ignore — the backend SOS is the primary channel.
    }
  }

  void _resetAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _sosSent = false;
          _isSending = false;
          _controller.reset();
        });
      }
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (_) => _onPressStart(),
          onLongPressEnd: (_) => _onPressEnd(),
          onLongPressCancel: _onPressEnd,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SizedBox(
                width: _buttonDiameter,
                height: _buttonDiameter,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circular progress ring around the button.
                    SizedBox(
                      width: _buttonDiameter,
                      height: _buttonDiameter,
                      child: CircularProgressIndicator(
                        value: _controller.value,
                        strokeWidth: 4,
                        backgroundColor: AppTheme.danger.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.danger,
                        ),
                      ),
                    ),
                    // Red gradient shield button.
                    Container(
                      width: _buttonDiameter - 10,
                      height: _buttonDiameter - 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5252), AppTheme.danger],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.danger.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _statusText,
            key: ValueKey(_statusText),
            style: TextStyle(
              color: _sosSent ? AppTheme.danger : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

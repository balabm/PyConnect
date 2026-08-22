import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A premium swipe-to-accept bar that prevents accidental taps.
///
/// The user must swipe a knob from left to right to accept a dispatch.
/// Haptic vibration increases in intensity as the swipe progresses:
///   - 25%: selectionClick
///   - 50%: mediumImpact
///   - 75%: heavyImpact
///   - 100% (complete): heavyImpact + lightImpact (success pattern)
///
/// If the swipe is released before reaching 100%, the knob springs back
/// to the start position.
class SwipeToAccept extends StatefulWidget {
  const SwipeToAccept({
    super.key,
    required this.label,
    required this.onAccept,
    this.color = AppTheme.emerald,
    this.height = 64,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onAccept;
  final Color color;
  final double height;
  final bool disabled;

  @override
  State<SwipeToAccept> createState() => _SwipeToAcceptState();
}

class _SwipeToAcceptState extends State<SwipeToAccept>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springController;
  double _dragProgress = 0.0;
  double _lastHapticThreshold = 0.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _triggerHapticForProgress(double progress) {
    // Trigger haptics at 25%, 50%, 75% thresholds
    final thresholds = [0.25, 0.50, 0.75];
    for (int i = 0; i < thresholds.length; i++) {
      if (progress >= thresholds[i] && _lastHapticThreshold < thresholds[i]) {
        switch (i) {
          case 0:
            HapticFeedback.selectionClick();
          case 1:
            HapticFeedback.mediumImpact();
          case 2:
            HapticFeedback.heavyImpact();
        }
        _lastHapticThreshold = thresholds[i];
        return;
      }
    }
  }

  void _onAccept() {
    // Success haptic pattern
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.lightImpact();
    });
    widget.onAccept();
  }

  void _springBack() {
    setState(() => _dragProgress = 0.0);
    _lastHapticThreshold = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: widget.color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSwipe = constraints.maxWidth - widget.height - 8;
          final knobOffset = _dragProgress * maxSwipe;

          return Stack(
            children: [
              // Label (fades as user swipes)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: (1.0 - _dragProgress * 1.5).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: widget.color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Progress fill (grows behind the knob)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: knobOffset + widget.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.color.withOpacity(0.3),
                          widget.color.withOpacity(0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Draggable knob
              Positioned(
                left: 4 + knobOffset,
                top: 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.disabled
                      ? null
                      : (details) {
                          setState(() {
                            _dragProgress =
                                (_dragProgress + details.delta.dx / maxSwipe)
                                    .clamp(0.0, 1.0);
                            _triggerHapticForProgress(_dragProgress);
                          });
                        },
                  onHorizontalDragEnd: widget.disabled
                      ? null
                      : (_) {
                          if (_dragProgress >= 0.95) {
                            _onAccept();
                            _springBack();
                          } else {
                            _springBack();
                          }
                        },
                  child: Container(
                    width: widget.height - 8,
                    height: widget.height - 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _dragProgress >= 0.95
                          ? Icons.check_rounded
                          : Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

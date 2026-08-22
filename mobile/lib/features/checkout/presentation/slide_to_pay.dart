import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A premium "Slide to Pay" bar that creates psychological commitment
/// through the physical act of swiping. Replaces standard tap buttons
/// in the checkout flow.
///
/// Features:
/// - Frosted glass blur background with heavy top shadow
/// - Progressive haptic feedback (selection → medium → heavy → success)
/// - Label fades as user swipes
/// - Icon morphs from chevron to check at 95% completion
/// - Spring back if released before threshold
class SlideToPay extends StatefulWidget {
  const SlideToPay({
    super.key,
    required this.amount,
    required this.label,
    required this.onPay,
    this.color = AppTheme.emerald,
    this.height = 64,
    this.disabled = false,
  });

  /// The payment amount to display (e.g., "₹450").
  final String amount;

  /// Label text (e.g., "Slide to Pay").
  final String label;

  /// Callback when the swipe is completed.
  final VoidCallback onPay;

  /// Accent color for the slider.
  final Color color;

  /// Height of the slider bar.
  final double height;

  /// Whether the slider is disabled (e.g., during processing).
  final bool disabled;

  @override
  State<SlideToPay> createState() => _SlideToPayState();
}

class _SlideToPayState extends State<SlideToPay>
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

  void _onPay() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.lightImpact();
    });
    widget.onPay();
  }

  void _springBack() {
    setState(() => _dragProgress = 0.0);
    _lastHapticThreshold = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: widget.color.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          // Heavy top shadow for sticky bar separation
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxSwipe = constraints.maxWidth - widget.height - 8;
              final knobOffset = _dragProgress * maxSwipe;

              return Stack(
                children: [
                  // Label + amount (fades as user swipes)
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - _dragProgress * 1.5).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: widget.color,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.label} ',
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              widget.amount,
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
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
                              widget.color.withOpacity(0.35),
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
                                _dragProgress = (_dragProgress +
                                        details.delta.dx / maxSwipe)
                                    .clamp(0.0, 1.0);
                                _triggerHapticForProgress(_dragProgress);
                              });
                            },
                      onHorizontalDragEnd: widget.disabled
                          ? null
                          : (_) {
                              if (_dragProgress >= 0.95) {
                                _onPay();
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
                              : Icons.arrow_forward_rounded,
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
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';

/// A floating, glassmorphic "Live Island" toast that persistently
/// shows a mini-progress bar and ETA at the top of the screen.
///
/// Unlike a standard [SnackBar], this widget is non-blocking — the
/// user can continue browsing the home screen while an order is
/// active. It persists until the order is complete or dismissed.
///
/// Place this as an overlay using a [Stack] or [OverlayEntry].
class LiveToast extends StatefulWidget {
  const LiveToast({
    super.key,
    required this.title,
    required this.statusText,
    required this.progress,
    this.etaMinutes,
    this.onTap,
    this.onDismiss,
    this.color = AppTheme.emerald,
  });

  /// Main title (e.g., "Order #12345").
  final String title;

  /// Status text (e.g., "Arriving in 12 mins").
  final String statusText;

  /// Progress value 0.0 to 1.0.
  final double progress;

  /// Optional ETA in minutes.
  final int? etaMinutes;

  /// Tap callback — typically navigates to the tracking screen.
  final VoidCallback? onTap;

  /// Dismiss callback.
  final VoidCallback? onDismiss;

  /// Accent color for the progress bar.
  final Color color;

  @override
  State<LiveToast> createState() => _LiveToastState();
}

class _LiveToastState extends State<LiveToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: AppDecorations.glassStrong(context),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Status icon with glow
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.color.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          Icons.two_wheeler,
                          color: widget.color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title + status + progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.charcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Mini progress bar
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                minHeight: 3,
                                backgroundColor:
                                    widget.color.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(
                                  widget.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dismiss button
                      GestureDetector(
                        onTap: () {
                          _slideController.reverse().then((_) {
                            widget.onDismiss?.call();
                          });
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppTheme.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A manager for showing/dismissing [LiveToast] overlays.
class LiveToastManager {
  LiveToastManager._();

  static OverlayEntry? _currentEntry;

  /// Shows a [LiveToast] as a persistent overlay at the top of the screen.
  static void show(
    BuildContext context, {
    required String title,
    required String statusText,
    required double progress,
    int? etaMinutes,
    VoidCallback? onTap,
    Color color = AppTheme.emerald,
  }) {
    dismiss();
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: LiveToast(
          title: title,
          statusText: statusText,
          progress: progress,
          etaMinutes: etaMinutes,
          onTap: onTap,
          onDismiss: dismiss,
          color: color,
        ),
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  /// Updates the current toast with new progress/status.
  static void update({
    required String statusText,
    required double progress,
    int? etaMinutes,
  }) {
    // OverlayEntry doesn't support direct updates — caller should
    // dismiss + show to update. This is a simplified API.
  }

  /// Dismisses the current toast if any.
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

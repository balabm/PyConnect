import 'package:flutter/material.dart';

import '../animations/haptic.dart';
import '../theme/app_theme.dart';

/// Premium toast notification system with icons, colors, and animations.
/// Use [AppToast.show] to display a toast from anywhere with a BuildContext.
enum ToastType { success, error, warning, info }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final colors = _colorsFor(type);
    final defaultIcon = _iconFor(type);

    AppHaptics.light();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        message: message,
        icon: icon ?? defaultIcon,
        color: colors.$1,
        backgroundColor: colors.$2,
        onDismiss: () => entry.remove(),
        duration: duration,
      ),
    );
    overlay.insert(entry);
  }

  static (Color, Color) _colorsFor(ToastType type) {
    return switch (type) {
      ToastType.success => (AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.95)),
      ToastType.error => (const Color(0xFFEF4444), const Color(0xFFEF4444).withValues(alpha: 0.95)),
      ToastType.warning => (AppTheme.coral, AppTheme.coral.withValues(alpha: 0.95)),
      ToastType.info => (AppTheme.sky, AppTheme.sky.withValues(alpha: 0.95)),
    };
  }

  static IconData _iconFor(ToastType type) {
    return switch (type) {
      ToastType.success => Icons.check_circle_rounded,
      ToastType.error => Icons.error_rounded,
      ToastType.warning => Icons.warning_rounded,
      ToastType.info => Icons.info_rounded,
    };
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onDismiss,
    required this.duration,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onDismiss;
  final Duration duration;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + AppSpacing.lg;
    return Positioned(
      top: topPadding,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: Colors.white, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

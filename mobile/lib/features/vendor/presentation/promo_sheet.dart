import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// One-tap flash promotion bottom sheet for pub/club owners.
///
/// **DEMO MOCKUP**: The "broadcast" action shows a radar animation and a
/// success message with a fake user count. There is no backend endpoint for
/// hyper-local push notification broadcasting yet. When the backend is ready,
/// replace [_broadcast] with a real API call to POST /api/vendor/flash-promo.
class PromoSheet extends StatefulWidget {
  const PromoSheet({super.key});

  /// Convenience method to show the sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PromoSheet(),
    );
  }

  @override
  State<PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<PromoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  bool _broadcasting = false;
  bool _broadcastDone = false;
  int _reachedUsers = 0;

  static const _presetPromos = [
    _PresetPromo(
      icon: Icons.local_bar,
      label: '1+1 on Drinks',
      subtitle: 'Buy one get one free — next 30 min',
      color: AppTheme.emerald,
    ),
    _PresetPromo(
      icon: Icons.female,
      label: 'Free Entry for Women',
      subtitle: 'Waive cover charge until 11 PM',
      color: Color(0xFFEC4899),
    ),
    _PresetPromo(
      icon: Icons.restaurant,
      label: '20% Off Food',
      subtitle: 'Flash discount on all food orders',
      color: Color(0xFF3B82F6),
    ),
    _PresetPromo(
      icon: Icons.celebration,
      label: 'Happy Hour Extended',
      subtitle: 'Extended to midnight — 50% off cocktails',
      color: AppTheme.gold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _broadcast(_PresetPromo promo) async {
    if (_broadcasting) return;
    AppHaptics.medium();
    setState(() {
      _broadcasting = true;
      _broadcastDone = false;
    });

    _radarController.reset();
    _radarController.forward();

    // Simulate the broadcast taking 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    setState(() {
      _broadcasting = false;
      _broadcastDone = true;
      _reachedUsers = 1200 + (DateTime.now().millisecond % 400); // 1200-1600
    });
    AppHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_broadcasting) ...[
            _RadarBroadcast(controller: _radarController),
            const SizedBox(height: 16),
            Center(
              child: Text('Broadcasting offer...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emerald,
                  )),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Sending push notification to nearby users',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ),
          ] else if (_broadcastDone) ...[
            _SuccessState(
              reachedUsers: _reachedUsers,
              onReset: () => setState(() => _broadcastDone = false),
            ),
          ] else ...[
            // Title
            Text('Flash Promo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
            const SizedBox(height: 4),
            Text('Send an instant offer to users within 3km',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 24),

            // Preset promo chips
            ..._presetPromos.map((promo) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PromoCard(
                    promo: promo,
                    onTap: () => _broadcast(promo),
                  ),
                )),

            const SizedBox(height: 8),
            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Promotions auto-expire after 30 minutes. Users receive a push notification with your venue name and offer.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetPromo {
  const _PresetPromo({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, required this.onTap});
  final _PresetPromo promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: promo.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: promo.color.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: promo.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(promo.icon, size: 22, color: promo.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(promo.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    Text(promo.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              Icon(Icons.send, size: 20, color: promo.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadarBroadcast extends StatelessWidget {
  const _RadarBroadcast({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            return CustomPaint(
              size: const Size(180, 180),
              painter: _RadarPainter(controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw expanding radar rings
    for (var i = 0; i < 3; i++) {
      final ringProgress = (progress + i * 0.33) % 1.0;
      final radius = maxRadius * ringProgress;
      final alpha = (1.0 - ringProgress) * 0.5;

      final paint = Paint()
        ..color = AppTheme.emerald.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
    }

    // Draw center dot
    final centerPaint = Paint()
      ..color = AppTheme.emerald
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, centerPaint);

    // Draw glow
    final glowPaint = Paint()
      ..color = AppTheme.emerald.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 16, glowPaint);

    // Draw sweeping arc
    final sweepAngle = progress * 2 * 3.14159265;
    final sweepPaint = Paint()
      ..color = AppTheme.emerald.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      sweepAngle - 0.5,
      0.5,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.reachedUsers, required this.onReset});
  final int reachedUsers;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle, size: 36, color: AppTheme.emerald),
        ),
        const SizedBox(height: 16),
        Text('Offer Broadcasted!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.emerald,
            )),
        const SizedBox(height: 8),
        Text(
          'Sent to $reachedUsers users within 3km',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'They have 30 minutes to walk in and claim',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.send),
            label: const Text('Send Another Offer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

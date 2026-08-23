import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';

/// One-tap flash promotion bottom sheet for pub/club owners.
///
/// Creates a real flash promo via POST /api/vendor/flash-promos. The
/// backend records the promo with a discount percentage, duration, and
/// title. The promo auto-expires after the duration.
class PromoSheet extends ConsumerStatefulWidget {
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
  ConsumerState<PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends ConsumerState<PromoSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  bool _broadcasting = false;
  bool _broadcastDone = false;
  String? _errorMessage;
  _PresetPromo? _selectedPromo;
  double _durationMin = 30; // minutes
  double _discountPct = 20; // percent

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

  Future<void> _broadcast() async {
    if (_broadcasting || _selectedPromo == null) return;
    AppHaptics.medium();
    setState(() {
      _broadcasting = true;
      _broadcastDone = false;
      _errorMessage = null;
    });

    _radarController.reset();
    _radarController.forward();

    try {
      final api = ref.read(vendorDashboardApiProvider);
      await api.createFlashPromo(CreateFlashPromoPayload(
        discountPercentage: _discountPct,
        durationMinutes: _durationMin.round(),
        title: _selectedPromo!.label,
        description: _selectedPromo!.subtitle,
      ));

      if (!mounted) return;
      setState(() {
        _broadcasting = false;
        _broadcastDone = true;
      });
      AppHaptics.success();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _broadcasting = false;
        _errorMessage = e.toString();
      });
    }
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
              child: Text('Creating flash promo...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.emerald,
                  )),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Recording promotion with the backend',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ),
          ] else if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text('Failed to create promo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.danger)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => setState(() => _errorMessage = null),
              child: const Text('Try Again'),
            ),
          ] else if (_broadcastDone) ...[
            _SuccessState(
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
            Text('Send an instant offer to nearby users',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 24),

            // Preset promo chips
            ..._presetPromos.map((promo) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PromoCard(
                    promo: promo,
                    isSelected: _selectedPromo == promo,
                    onTap: () => setState(() => _selectedPromo = promo),
                  ),
                )),

            const SizedBox(height: 16),

            // Duration slider
            if (_selectedPromo != null) ...[
              _SliderRow(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: '${_durationMin.round()} min',
                slider: Slider(
                  value: _durationMin,
                  min: 15,
                  max: 120,
                  divisions: 7,
                  activeColor: AppTheme.emerald,
                  onChanged: (v) => setState(() => _durationMin = v),
                ),
              ),
              const SizedBox(height: 12),

              // Discount slider
              _SliderRow(
                icon: Icons.percent,
                label: 'Discount',
                value: '${_discountPct.round()}% off',
                slider: Slider(
                  value: _discountPct,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  activeColor: AppTheme.emerald,
                  onChanged: (v) => setState(() => _discountPct = v),
                ),
              ),
              const SizedBox(height: 20),

              // Slide-to-confirm broadcast button
              _SlideToConfirm(
                promo: _selectedPromo!,
                onConfirm: _broadcast,
              ),
              const SizedBox(height: 12),
            ],

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
                      'Promotions auto-expire after the duration. The discount is visible to consumers browsing your venue.',
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
  const _PromoCard({required this.promo, required this.onTap, this.isSelected = false});
  final _PresetPromo promo;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: promo.color.withValues(alpha: isSelected ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: promo.color.withValues(alpha: isSelected ? 0.5 : 0.2),
              width: isSelected ? 2 : 1,
            ),
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
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 22,
                color: promo.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.slider,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.emerald),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emerald,
                )),
          ],
        ),
        slider,
      ],
    );
  }
}

/// Slide-to-confirm button to prevent accidental promo broadcasts.
class _SlideToConfirm extends StatefulWidget {
  const _SlideToConfirm({required this.promo, required this.onConfirm});
  final _PresetPromo promo;
  final VoidCallback onConfirm;

  @override
  State<_SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<_SlideToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragExtent = 0;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - 72; // thumb width
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_confirmed) return;
            setState(() {
              _dragExtent = (_dragExtent + details.delta.dx).clamp(0, maxDrag);
            });
          },
          onHorizontalDragEnd: (details) {
            if (_confirmed) return;
            if (_dragExtent >= maxDrag * 0.85) {
              setState(() => _confirmed = true);
              AppHaptics.success();
              widget.onConfirm();
            } else {
              // Snap back
              _controller.reset();
              setState(() => _dragExtent = 0);
            }
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: widget.promo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.promo.color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                // Label
                Center(
                  child: Text(
                    _confirmed ? 'BROADCASTING...' : 'SLIDE TO BROADCAST',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: widget.promo.color,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                // Sliding thumb
                Positioned(
                  left: _dragExtent,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: widget.promo.color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.promo.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check : Icons.arrow_forward,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
  const _SuccessState({required this.onReset});
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
        Text('Flash Promo Created!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.emerald,
            )),
        const SizedBox(height: 8),
        Text(
          'Your promotion is now live and will auto-expire after the duration.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.send),
            label: const Text('Create Another Promo'),
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

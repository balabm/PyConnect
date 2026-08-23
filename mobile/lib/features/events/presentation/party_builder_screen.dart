import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// Party Builder screen — a multi-step "Party in a Box" cart builder.
///
/// Lets users bundle talent (DJ, bartender, bouncer), hardware rentals
/// (speakers, hookahs, lights), and catering (kegs, platters) for a
/// scheduled high-ticket event at their villa.
///
/// This is a vision/UI mockup for the pitch demo. Backend escrow,
/// gig dispatch, and asset protection will be wired in Phase XX.
class PartyBuilderScreen extends StatefulWidget {
  const PartyBuilderScreen({super.key});

  @override
  State<PartyBuilderScreen> createState() => _PartyBuilderScreenState();
}

class _PartyBuilderScreenState extends State<PartyBuilderScreen> {
  int _currentStep = 0;
  DateTime? _selectedDateTime;

  // Selections
  final Set<String> _selectedTalent = {};
  final Set<String> _selectedHardware = {};
  final Set<String> _selectedCatering = {};

  static const _steps = ['Date & Time', 'Talent', 'Hardware', 'Catering'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Host a Party'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1530103862676-de8c9debad1d?w=800',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.emerald.withValues(alpha: 0.3), AppTheme.charcoal],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppTheme.charcoal.withValues(alpha: 0.8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          // Stepper
          SliverToBoxAdapter(
            child: _buildStepper(isDark),
          ),
          // Step content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(isDark),
            ),
          ),
          // Summary + CTA
          SliverToBoxAdapter(
            child: _buildSummaryBar(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final completed = i ~/ 2 < _currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: completed ? AppTheme.emerald : (isDark ? Colors.white12 : Colors.black12),
              ),
            );
          }
          final step = i ~/ 2;
          final isCurrent = step == _currentStep;
          final isCompleted = step < _currentStep;
          return GestureDetector(
            onTap: () => setState(() => _currentStep = step),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.emerald
                        : isCurrent
                            ? AppTheme.emerald.withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                    border: Border.all(
                      color: isCurrent || isCompleted ? AppTheme.emerald : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Text(
                            '${step + 1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCurrent ? AppTheme.emerald : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _steps[step],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? (isDark ? Colors.white : AppTheme.charcoal)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    return switch (_currentStep) {
      0 => _buildDateTimeStep(isDark),
      1 => _buildTalentStep(isDark),
      2 => _buildHardwareStep(isDark),
      3 => _buildCateringStep(isDark),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Step 1: Date & Time ──
  Widget _buildDateTimeStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When is the party?',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.charcoal),
        ),
        const SizedBox(height: 4),
        Text(
          'Bookings must be made at least 24 hours in advance.',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 20),
        // Quick presets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildDatePreset('Tomorrow Night', isDark),
            _buildDatePreset('This Weekend', isDark),
            _buildDatePreset('Next Weekend', isDark),
          ],
        ),
        const SizedBox(height: 16),
        // Custom date picker
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now.add(const Duration(days: 1)),
              firstDate: now.add(const Duration(hours: 24)),
              lastDate: now.add(const Duration(days: 90)),
            );
            if (picked != null && mounted) {
              final time = await showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 20, minute: 0),
              );
              if (time != null && mounted) {
                setState(() {
                  _selectedDateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                });
              }
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: const Text('Pick a custom date & time'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.emerald,
            side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        if (_selectedDateTime != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: AppTheme.emerald, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppTheme.emerald),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePreset(String label, bool isDark) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        final now = DateTime.now();
        setState(() {
          _selectedDateTime = now.add(const Duration(days: 1)).copyWith(hour: 20, minute: 0);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.emerald.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.emerald)),
      ),
    );
  }

  // ── Step 2: Talent ──
  Widget _buildTalentStep(bool isDark) {
    final talent = [
      _TalentOption(id: 'dj', name: 'Private DJ', icon: Icons.graphic_eq, price: 5000, duration: '4 hours', desc: 'Professional DJ with sound setup'),
      _TalentOption(id: 'bartender', name: 'Mixologist', icon: Icons.local_bar, price: 3000, duration: '4 hours', desc: 'Craft cocktail bartender'),
      _TalentOption(id: 'bouncer', name: 'Bouncer', icon: Icons.security, price: 2000, duration: '4 hours', desc: 'Licensed security for door control'),
    ];
    return _buildSelectionGrid(talent, _selectedTalent, isDark);
  }

  // ── Step 3: Hardware ──
  Widget _buildHardwareStep(bool isDark) {
    final hardware = [
      _TalentOption(id: 'speakers', name: 'JBL PartyBox', icon: Icons.speaker, price: 1500, duration: 'per night', desc: 'Professional party speaker system'),
      _TalentOption(id: 'hookah', name: 'Hookah Set (2)', icon: Icons.air, price: 800, duration: 'per night', desc: 'Premium hookah with flavors'),
      _TalentOption(id: 'lights', name: 'Strobe & LED Lights', icon: Icons.lightbulb, price: 1000, duration: 'per night', desc: 'Party lighting setup'),
    ];
    return _buildSelectionGrid(hardware, _selectedHardware, isDark);
  }

  // ── Step 4: Catering ──
  Widget _buildCateringStep(bool isDark) {
    final catering = [
      _TalentOption(id: 'keg', name: 'Craft Beer Keg (5L)', icon: Icons.sports_bar, price: 2500, duration: 'per keg', desc: 'Local craft beer on tap'),
      _TalentOption(id: 'platter', name: 'Party Platter (20 ppl)', icon: Icons.restaurant, price: 3500, duration: 'per platter', desc: 'Bulk catering from Fuoco Pizzeria'),
      _TalentOption(id: 'shots', name: 'Shot Bar Setup', icon: Icons.liquor, price: 1800, duration: '50 shots', desc: 'Pre-mixed shot bar with 3 varieties'),
    ];
    return _buildSelectionGrid(catering, _selectedCatering, isDark);
  }

  Widget _buildSelectionGrid(List<_TalentOption> options, Set<String> selected, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select what you need',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.charcoal),
        ),
        const SizedBox(height: 16),
        ...options.map((opt) {
          final isSelected = selected.contains(opt.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                AppHaptics.light();
                setState(() {
                  if (isSelected) {
                    selected.remove(opt.id);
                  } else {
                    selected.add(opt.id);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.emerald.withValues(alpha: 0.06)
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.emerald.withValues(alpha: 0.4) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.emerald.withValues(alpha: 0.12) : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(opt.icon, color: isSelected ? AppTheme.emerald : (isDark ? Colors.white60 : Colors.black54), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.charcoal)),
                          const SizedBox(height: 2),
                          Text(opt.desc, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\u20B9${opt.price}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.emerald)),
                        Text(opt.duration, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppTheme.emerald : Colors.transparent,
                        border: Border.all(color: isSelected ? AppTheme.emerald : (isDark ? Colors.white24 : Colors.black26), width: 2),
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Summary Bar ──
  Widget _buildSummaryBar(bool isDark) {
    final total = _calculateTotal();
    final advance = (total * 0.3).round();
    final canProceed = _selectedDateTime != null && (_selectedTalent.isNotEmpty || _selectedHardware.isNotEmpty || _selectedCatering.isNotEmpty);
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (total > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Estimated Total', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                  Text('\u20B9$total', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppTheme.charcoal)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('30% Advance to Book', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
                  Text('\u20B9$advance', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.emerald)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black54,
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: canProceed
                        ? () {
                            AppHaptics.light();
                            if (isLastStep) {
                              _showBookingConfirmation(total, advance);
                            } else {
                              setState(() => _currentStep++);
                            }
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      disabledBackgroundColor: AppTheme.emerald.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isLastStep ? 'Book Party (\u20B9$advance advance)' : 'Continue',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _calculateTotal() {
    int total = 0;
    for (final id in _selectedTalent) {
      total += _getTalentPrice(id);
    }
    for (final id in _selectedHardware) {
      total += _getHardwarePrice(id);
    }
    for (final id in _selectedCatering) {
      total += _getCateringPrice(id);
    }
    return total;
  }

  int _getTalentPrice(String id) => switch (id) {
        'dj' => 5000,
        'bartender' => 3000,
        'bouncer' => 2000,
        _ => 0,
      };

  int _getHardwarePrice(String id) => switch (id) {
        'speakers' => 1500,
        'hookah' => 800,
        'lights' => 1000,
        _ => 0,
      };

  int _getCateringPrice(String id) => switch (id) {
        'keg' => 2500,
        'platter' => 3500,
        'shots' => 1800,
        _ => 0,
      };

  void _showBookingConfirmation(int total, int advance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.emerald, size: 28),
            SizedBox(width: 12),
            Text('Party Requested!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your party booking for \u20B9$total has been submitted.'),
            const SizedBox(height: 8),
            Text('A 30% advance (\u20B9$advance) will be charged to confirm availability. Our team will confirm within 2 hours.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: AppTheme.emerald, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remaining 70% held in escrow — released only after your party.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _TalentOption {
  final String id;
  final String name;
  final IconData icon;
  final int price;
  final String duration;
  final String desc;

  const _TalentOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.price,
    required this.duration,
    required this.desc,
  });
}

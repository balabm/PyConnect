import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// "God Mode" Crowd Matrix dashboard for pub/club owners.
///
/// **DEMO MOCKUP**: The data shown here is hardcoded to simulate a live
/// Saturday night at a Pondicherry pub. There is no backend endpoint for
/// gender tracking, cover charge ledgers, or VIP heatmaps yet. This screen
/// exists to show venue owners the *vision* of the analytics dashboard they
/// will get when the full telemetry pipeline is wired.
///
/// When the backend is ready, replace the [_MockData] fields with live API
/// calls (venue occupancy, ticket scans, cover charge totals, gender split
/// from ticket metadata).
class CrowdDashboardScreen extends StatefulWidget {
  const CrowdDashboardScreen({super.key, this.venueName = 'Drunken Daddy'});

  final String venueName;

  @override
  State<CrowdDashboardScreen> createState() => _CrowdDashboardScreenState();
}

class _CrowdDashboardScreenState extends State<CrowdDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  // Mock data simulating a live Saturday night
  int _currentOccupancy = 142;
  final int _maxCapacity = 200;
  int _maleCount = 57;
  int _femaleCount = 48;
  int _coupleCount = 37;
  int _coverCollected = 124000;
  int _vipMembers = 23;
  int _firstTimers = 89;
  int _regulars = 53;
  int _averageAge = 24;
  int _liveRevenue = 29000;

  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    // Simulate live updates every 5 seconds
    _liveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        // Random walk the occupancy within a realistic range
        final delta = _randomInt(-3, 5);
        _currentOccupancy = (_currentOccupancy + delta).clamp(120, 195);
        _maleCount = (_maleCount + _randomInt(-2, 2)).clamp(40, 70);
        _femaleCount = (_femaleCount + _randomInt(-2, 2)).clamp(35, 60);
        _coupleCount = _currentOccupancy - _maleCount - _femaleCount;
        if (_coupleCount < 20) _coupleCount = 20;
        _coverCollected += _randomInt(0, 2000);
        _liveRevenue += _randomInt(500, 3000);
        _vipMembers = (_vipMembers + _randomInt(-1, 1)).clamp(15, 35);
        _firstTimers = (_firstTimers + _randomInt(-2, 3)).clamp(70, 110);
        _regulars = _currentOccupancy - _firstTimers;
        _averageAge = (_averageAge + _randomInt(-1, 1)).clamp(21, 28);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveTimer?.cancel();
    super.dispose();
  }

  int _randomInt(int min, int max) =>
      min + Random().nextInt(max - min + 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final occupancyPct = (_currentOccupancy / _maxCapacity * 100).round();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('${widget.venueName} — Live'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _LiveIndicator(pulseController: _pulseController),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          AppHaptics.light();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Occupancy hero card
              _OccupancyHero(
                current: _currentOccupancy,
                max: _maxCapacity,
                pct: occupancyPct,
                cardColor: cardColor,
                pulseController: _pulseController,
              ),
              const SizedBox(height: 12),

              // Quick stats row: Average Age + Live Revenue
              Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.cake_outlined,
                      label: 'Avg Age',
                      value: '$_averageAge',
                      color: const Color(0xFF8B5CF6),
                      cardColor: cardColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.trending_up,
                      label: 'Live Revenue',
                      value: '\u20B9${_formatK(_liveRevenue)}',
                      color: AppTheme.emerald,
                      cardColor: cardColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender split donut chart
              _SectionTitle(title: 'Crowd Composition', icon: Icons.pie_chart),
              const SizedBox(height: 12),
              _CrowdDonut(
                male: _maleCount,
                female: _femaleCount,
                couple: _coupleCount,
                cardColor: cardColor,
              ),
              const SizedBox(height: 20),

              // Cover charge + revenue
              _SectionTitle(title: 'Cover Charges', icon: Icons.payments),
              const SizedBox(height: 12),
              _RevenueRow(
                coverCollected: _coverCollected,
                cardColor: cardColor,
              ),
              const SizedBox(height: 20),

              // VIP Heatmap
              _SectionTitle(title: 'Audience Quality', icon: Icons.verified_user),
              const SizedBox(height: 12),
              _AudienceQuality(
                vips: _vipMembers,
                firstTimers: _firstTimers,
                regulars: _regulars,
                cardColor: cardColor,
              ),
              const SizedBox(height: 20),

              // Anti-fraud entry log
              _SectionTitle(title: 'Door Log (Anti-Fraud)', icon: Icons.qr_code_scanner),
              const SizedBox(height: 12),
              _DoorLog(cardColor: cardColor),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cardColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              )),
        ],
      ),
    );
  }
}

String _formatK(int amount) {
  if (amount >= 1000) {
    final k = amount / 1000.0;
    return k == k.roundToDouble() ? '${k.round()}K' : k.toStringAsFixed(1);
  }
  return amount.toString();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.emerald),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            )),
      ],
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.pulseController});
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.emerald.withValues(alpha: 0.4 + 0.6 * pulseController.value),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: 0.5 * pulseController.value),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.emerald,
                  letterSpacing: 1.2,
                )),
          ],
        );
      },
    );
  }
}

class _OccupancyHero extends StatelessWidget {
  const _OccupancyHero({
    required this.current,
    required this.max,
    required this.pct,
    required this.cardColor,
    required this.pulseController,
  });

  final int current;
  final int max;
  final int pct;
  final Color cardColor;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    final isNearCapacity = pct >= 80;
    final accent = isNearCapacity ? AppTheme.danger : AppTheme.emerald;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.15), cardColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Occupancy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              if (isNearCapacity)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('NEAR CAPACITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.danger,
                        letterSpacing: 0.8,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$current',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1,
                  )),
              Text(' / $max',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
              const Spacer(),
              Text('$pct%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrowdDonut extends StatelessWidget {
  const _CrowdDonut({
    required this.male,
    required this.female,
    required this.couple,
    required this.cardColor,
  });

  final int male;
  final int female;
  final int couple;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final total = male + female + couple;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 45,
                    sections: [
                      PieChartSectionData(
                        value: male.toDouble(),
                        color: const Color(0xFF3B82F6), // Blue
                        radius: 28,
                        title: '${((male / total) * 100).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: female.toDouble(),
                        color: const Color(0xFFEC4899), // Pink
                        radius: 28,
                        title: '${((female / total) * 100).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: couple.toDouble(),
                        color: AppTheme.emerald,
                        radius: 28,
                        title: '${((couple / total) * 100).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    Text('inside',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(
                  color: const Color(0xFF3B82F6),
                  label: 'Stag (Male)',
                  count: male,
                  total: total,
                ),
                const SizedBox(height: 12),
                _LegendItem(
                  color: const Color(0xFFEC4899),
                  label: 'Stag (Female)',
                  count: female,
                  total: total,
                ),
                const SizedBox(height: 12),
                _LegendItem(
                  color: AppTheme.emerald,
                  label: 'Couples',
                  count: couple,
                  total: total,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = ((count / total) * 100).round();
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
        ),
        Text('$count ($pct%)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      ],
    );
  }
}

class _RevenueRow extends StatelessWidget {
  const _RevenueRow({required this.coverCollected, required this.cardColor});
  final int coverCollected;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppTheme.emerald, size: 20),
                  const SizedBox(width: 8),
                  Text('Total Cover Collected',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                ],
              ),
              Text('\u20B9${_formatRupees(coverCollected)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.emerald,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 16, color: AppTheme.emerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('T+0 Settlement: \u20B9${_formatRupees(coverCollected)} already in your bank account',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.emerald,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRupees(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      final k = amount / 1000;
      return k == k.roundToDouble() ? '${k.round()}K' : k.toStringAsFixed(1);
    }
    return amount.toString();
  }
}

class _AudienceQuality extends StatelessWidget {
  const _AudienceQuality({
    required this.vips,
    required this.firstTimers,
    required this.regulars,
    required this.cardColor,
  });

  final int vips;
  final int firstTimers;
  final int regulars;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          _QualityRow(
            icon: Icons.verified,
            color: AppTheme.gold,
            label: 'PY Prime Members',
            count: vips,
            subtitle: 'High-spending regulars',
          ),
          const Divider(height: 24),
          _QualityRow(
            icon: Icons.person_outline,
            color: AppTheme.emerald,
            label: 'Regulars',
            count: regulars,
            subtitle: 'Visited 3+ times',
          ),
          const Divider(height: 24),
          _QualityRow(
            icon: Icons.person_add_outlined,
            color: const Color(0xFF3B82F6),
            label: 'First-Timers',
            count: firstTimers,
            subtitle: 'New tonight',
          ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
        Text('$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            )),
      ],
    );
  }
}

class _DoorLog extends StatelessWidget {
  const _DoorLog({required this.cardColor});
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('21:42', 'QR-SCANNED', 'Couple Entry', AppTheme.emerald),
      ('21:38', 'QR-SCANNED', 'Stag (Male)', const Color(0xFF3B82F6)),
      ('21:35', 'WALK-IN', 'Cover paid at door', AppTheme.gold),
      ('21:31', 'QR-SCANNED', 'Stag (Female)', const Color(0xFFEC4899)),
      ('21:28', 'BLOCKED', 'Duplicate QR blocked', AppTheme.danger),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: entries.map((e) {
          final (time, status, detail, color) = e;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.5,
                      )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(detail,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                ),
                Icon(Icons.check_circle, size: 16, color: color),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

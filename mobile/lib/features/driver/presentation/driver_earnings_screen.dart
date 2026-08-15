import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers.dart';

final driverEarningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(ridesApiProvider);
  return await api.getDriverEarnings();
});

class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(driverEarningsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () {
          AppHaptics.light();
          return ref.refresh(driverEarningsProvider.future);
        },
        child: earningsAsync.when(
          loading: () => const ShimmerList(withImage: false, count: 5),
          error: (e, _) => ErrorState(message: e.toString()),
          data: (data) => _EarningsBody(data: data),
        ),
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  const _EarningsBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final todayEarnings = data['todayEarnings'] ?? 0;
    final weekEarnings = data['weekEarnings'] ?? 0;
    final monthEarnings = data['monthEarnings'] ?? 0;
    final todayRides = data['todayRides'] ?? 0;
    final weekRides = data['weekRides'] ?? 0;
    final monthRides = data['monthRides'] ?? 0;
    final avgRating = (data['avgRating'] as num?)?.toDouble() ?? 5.0;
    final recentRides = data['recentRides'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's earnings - big card
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Today\'s Earnings', style: TextStyle(color: AppTheme.emerald, fontSize: 14)),
                const SizedBox(height: 8),
                Text('\u20B9$todayEarnings', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car, color: AppTheme.emerald, size: 16),
                    const SizedBox(width: 4),
                    Text('$todayRides rides today', style: const TextStyle(color: AppTheme.emerald)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Week & Month stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'This Week',
                  earnings: '\u20B9$weekEarnings',
                  rides: '$weekRides rides',
                  icon: Icons.calendar_view_week,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'This Month',
                  earnings: '\u20B9$monthEarnings',
                  rides: '$monthRides rides',
                  icon: Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rating card
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: AppTheme.gold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                RatingStars(rating: avgRating, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 0% commission banner
          AppCard(
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.savings, color: AppTheme.emerald, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('0% Commission', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('100% of ride fare goes to you. No hidden cuts.', style: TextStyle(color: AppTheme.emerald, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Recent rides
          const Text('Recent Rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (recentRides.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No completed rides yet',
              subtitle: 'Your completed rides will appear here',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentRides.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final ride = recentRides[index] as Map<String, dynamic>;
                final earnings = ride['earnings'] ?? 0;
                final distance = ride['distanceKm'] ?? 0;
                final duration = ride['durationMin'] ?? 0;
                final completedAt = ride['completedAt'] as String? ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                  title: Text('\u20B9$earnings', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$distance km · $duration min · ${_formatDate(completedAt)}', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20),
                );
              },
            ),
          const SizedBox(height: 24),
          // Profile section (merged from separate Profile tab)
          const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.person_outline,
                  title: 'Account Details',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'KYC Documents',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.security_outlined,
                  title: 'Safety Settings',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'Help & Support',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.earnings, required this.rides, required this.icon});
  final String title;
  final String earnings;
  final String rides;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 4),
          Text(earnings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(rides, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.emerald),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onTap,
    );
  }
}

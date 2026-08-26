import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Safety settings screen for the Captain app.
/// Links to existing safety features: SOS, emergency contacts, ride sharing.
class DriverSafetySettingsScreen extends StatelessWidget {
  const DriverSafetySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Safety status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: AppTheme.emerald, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your safety features are active. Stay alert and drive safe.',
                    style: TextStyle(
                      color: AppTheme.emerald,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Safety features
          const Text(
            'Safety Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _SafetyFeatureCard(
            icon: Icons.sos,
            title: 'SOS Emergency Button',
            description: 'Long-press the red shield button on your dashboard to alert emergency services and PY Connect support with your live location.',
            status: 'Active',
            statusColor: AppTheme.emerald,
            onTap: () => context.push('/'),
          ),
          _SafetyFeatureCard(
            icon: Icons.contact_phone_outlined,
            title: 'Emergency Contacts',
            description: 'Manage your emergency contacts who will be notified when you trigger an SOS alert.',
            status: 'Manage',
            statusColor: AppTheme.emerald,
            onTap: () => context.push('/emergency-contacts'),
          ),
          _SafetyFeatureCard(
            icon: Icons.share_location,
            title: 'Trip Sharing',
            description: 'Share your live trip location with a trusted contact so they can track your journey in real time.',
            status: 'Active during rides',
            statusColor: AppTheme.emerald,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip sharing is available during active rides from the ride screen.'),
                ),
              );
            },
          ),
          _SafetyFeatureCard(
            icon: Icons.verified_user_outlined,
            title: 'Rider OTP Verification',
            description: 'Always verify the rider\'s OTP before starting the trip. This prevents unauthorized pickups.',
            status: 'Required',
            statusColor: AppTheme.emerald,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('OTP verification is mandatory before starting every ride.'),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Safety tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: AppTheme.gold, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Safety Tips',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._safetyTips.map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('\u2022  ', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _safetyTips = [
    'Always verify the rider\'s OTP before starting the ride',
    'Follow traffic rules and speed limits at all times',
    'Use the SOS button if you feel unsafe during a ride',
    'Keep your emergency contacts updated',
    'Share your trip with a trusted contact for long rides',
    'Park in well-lit areas when waiting for riders',
    'Report any incidents through the Help screen immediately',
  ];
}

class _SafetyFeatureCard extends StatelessWidget {
  const _SafetyFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.emerald, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Safety settings screen for the Captain app.
///
/// This is a placeholder screen that honestly tells the driver which
/// safety features are planned but not yet available. No mock data —
/// just a truthful "coming soon" state.
class DriverSafetySettingsScreen extends StatelessWidget {
  const DriverSafetySettingsScreen({super.key});

  static const _plannedFeatures = [
    {
      'icon': Icons.sos,
      'title': 'SOS Emergency Button',
      'description': 'One-tap alert to PY Connect support and your emergency contacts with live location sharing.',
    },
    {
      'icon': Icons.share_location,
      'title': 'Ride Sharing',
      'description': 'Share your live trip location with a trusted contact so they can track your journey.',
    },
    {
      'icon': Icons.contact_phone_outlined,
      'title': 'Emergency Contacts',
      'description': 'Add up to 3 emergency contacts who will be notified if you trigger an SOS alert.',
    },
    {
      'icon': Icons.shield_outlined,
      'title': 'Ride Verification',
      'description': 'Verify rider identity via OTP before starting a trip. Prevents unauthorized pickups.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.construction, color: AppTheme.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Safety features are being built and will be available soon.',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Planned Safety Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._plannedFeatures.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlannedFeatureCard(
                  icon: f['icon'] as IconData,
                  title: f['title'] as String,
                  description: f['description'] as String,
                ),
              )),
        ],
      ),
    );
  }
}

class _PlannedFeatureCard extends StatelessWidget {
  const _PlannedFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
    );
  }
}

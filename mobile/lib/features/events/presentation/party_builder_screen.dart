import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// Party Builder entry point — now redirects to the clean P2P event creator.
///
/// The old "Party in a Box" bundle (talent, hookahs, catering) has been
/// replaced with a streamlined event creator focused on equipment rentals
/// and P2P ticketing. This screen serves as a landing page that directs
/// users to the new flow.
class PartyBuilderScreen extends StatelessWidget {
  const PartyBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host an Event'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.coral, AppTheme.coralLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.celebration, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create Your Event',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Host a private event, sell tickets, manage RSVPs, and scan guests at the door. Rent AV equipment from local vendors.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _FeatureRow(
                icon: Icons.speaker,
                title: 'Equipment Rentals',
                subtitle: 'Speakers, lights, fog machines from local vendors',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.confirmation_number,
                title: 'Ticket Sales',
                subtitle: 'Free RSVP or paid tickets with QR check-in',
              ),
              const SizedBox(height: 16),
              _FeatureRow(
                icon: Icons.qr_code_scanner,
                title: 'Guest Scanner',
                subtitle: 'Scan QR tickets at the door as the host',
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  AppHaptics.light();
                  context.push('/create-party');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Event',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  AppHaptics.light();
                  context.push('/events');
                },
                child: const Text('Browse Events'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  context.push('/equipment');
                },
                icon: const Icon(Icons.speaker),
                label: const Text('Rent Equipment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.emerald.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.emerald),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

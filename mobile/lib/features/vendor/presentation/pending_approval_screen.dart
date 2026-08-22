import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/vendor_auth_controller.dart';

/// Screen shown to newly registered or not-yet-approved partners after OTP.
/// Displays the current approval status, a support contact, and a sign-out
/// action so they can re-check after the admin has reviewed their profile.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vendorAuthControllerProvider).valueOrNull;
    final isRejected = session?.status == 'Rejected';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected ? Icons.cancel_outlined : Icons.hourglass_top_outlined,
                size: 80,
                color: isRejected ? AppTheme.danger : AppTheme.warning,
              ),
              const SizedBox(height: 24),
              Text(
                isRejected ? 'Application Rejected' : 'Application Under Review',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isRejected
                    ? (session?.rejectionReason ?? 'Your partner application was not approved.')
                    : 'Your partner profile is pending admin approval. You will be notified once it is reviewed.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (session?.vendorName.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                _InfoRow(label: 'Business', value: session!.vendorName),
                _InfoRow(label: 'Category', value: session.category),
                _InfoRow(label: 'Phone', value: session.phone),
              ],
              const SizedBox(height: 32),
              _InfoCard(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.headset_mic_outlined),
                      title: Text('Need help?'),
                      subtitle: Text('support@pyconnect.in'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.phone_outlined),
                      title: Text('Call support'),
                      subtitle: Text('+91 94439 12345'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        AppHaptics.light();
                        // In a real build this launches tel: +919443912345
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  AppHaptics.light();
                  ref.invalidate(vendorAuthControllerProvider);
                },
                icon: Icon(Icons.refresh),
                label: Text('Check status again'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  AppHaptics.light();
                  ref.read(vendorAuthControllerProvider.notifier).signOut();
                },
                icon: Icon(Icons.logout),
                label: Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: child,
      ),
    );
  }
}

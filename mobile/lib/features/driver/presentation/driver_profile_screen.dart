import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../application/driver_providers.dart';

/// Captain profile hub with quick links to KYC, earnings, and sign-out.
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(driverWalletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Captain Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            child: Column(
              children: [
                walletAsync.when(
                  loading: () => const ShimmerList(count: 1, withImage: false),
                  error: (_, __) => const ListTile(
                    title: Text('Wallet unavailable'),
                    leading: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  data: (wallet) => ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Earnings'),
                    subtitle: Text('₹${wallet.balance.toStringAsFixed(0)} available'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => ref.read(driverSelectedTabProvider.notifier).state = 2,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('KYC Verification'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/kyc'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              AppHaptics.light();
              ref.read(authControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/referral_api.dart';

final referralApiProvider = Provider<ReferralApi>((ref) {
  return ReferralApi(ref.watch(apiClientProvider));
});

final referralInfoProvider = FutureProvider<ReferralInfoModel>((ref) async {
  return ref.watch(referralApiProvider).getMyReferralInfo();
});

/// Referral program screen — shows the user's referral code, share button,
/// and stats (total referred, completed, pending, total earned).
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _applyController = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _applyController.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _applyController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a referral code'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    setState(() => _applying = true);
    try {
      final result = await ref.read(referralApiProvider).applyReferralCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.emerald : AppTheme.warning,
        ),
      );
      if (result.success) {
        _applyController.clear();
        ref.invalidate(referralInfoProvider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply code: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(referralInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Friends')),
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('Could not load referral info', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(referralInfoProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (info) => RefreshIndicator(
          onRefresh: () async => ref.refresh(referralInfoProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Hero card
              _HeroCard(info: info),
              const SizedBox(height: 24),
              // Share section
              _ShareSection(info: info),
              const SizedBox(height: 24),
              // Apply referral code section
              _ApplyCodeSection(
                controller: _applyController,
                applying: _applying,
                onApply: _applyCode,
              ),
              const SizedBox(height: 24),
              // Stats grid
              Text(
                'Your Impact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.group_add, label: 'Invited', value: '${info.totalReferred}', color: AppTheme.info)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.check_circle, label: 'Completed', value: '${info.completed}', color: AppTheme.emerald)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.hourglass_top, label: 'Pending', value: '${info.pending}', color: AppTheme.warning)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.account_balance_wallet, label: 'Earned', value: '\u20B9${info.totalEarned.toStringAsFixed(0)}', color: AppTheme.gold)),
                ],
              ),
              const SizedBox(height: 32),
              // How it works
              _HowItWorksSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.info});
  final ReferralInfoModel info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.emerald.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Give \u20B950, Get \u20B950',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Invite friends to PY Connect. When they join, you both get \u20B950 in your wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          // Referral code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.referralCode.isEmpty ? 'Loading...' : info.referralCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                  onPressed: info.referralCode.isEmpty
                      ? null
                      : () {
                          AppHaptics.light();
                          Clipboard.setData(ClipboardData(text: info.referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Referral code copied!')),
                          );
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyCodeSection extends StatelessWidget {
  const _ApplyCodeSection({
    required this.controller,
    required this.applying,
    required this.onApply,
  });

  final TextEditingController controller;
  final bool applying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.redeem, size: 20, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                'Have a referral code?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a friend\'s code to earn \u20B950 instantly.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    isDense: true,
                  ),
                  onSubmitted: (_) => applying ? null : onApply(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: applying ? null : onApply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.white,
                ),
                child: applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareSection extends StatelessWidget {
  const _ShareSection({required this.info});
  final ReferralInfoModel info;

  @override
  Widget build(BuildContext context) {
    final shareText = 'Join me on PY Connect! Use my referral code ${info.referralCode} and get \u20B950 in your wallet. '
        'Download from https://pyconnect.run.place/app/';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share Your Code',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: info.referralCode.isEmpty
                    ? null
                    : () {
                        AppHaptics.light();
                        Share.share(shareText, subject: 'Join PY Connect');
                      },
                icon: const Icon(Icons.share),
                label: const Text('Share via WhatsApp'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.emerald,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Share your code', 'Send your referral code to friends via WhatsApp or copy it.'),
      ('They sign up', 'Your friend downloads PY Connect and enters your code during onboarding.'),
      ('You both earn', 'You get \u20B950 and your friend gets \u20B950 in their wallet.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$1,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/modern_animations.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';
import '../domain/driver_models.dart';
import 'widgets/dispatch_task_card.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PY Connect Captain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user_outlined),
            tooltip: 'KYC Verification',
            onPressed: () {
              AppHaptics.light();
              context.go('/kyc');
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '0% Commission',
                style: TextStyle(
                  color: AppTheme.emerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tasks', icon: Icon(Icons.list)),
            Tab(text: 'Wallet', icon: Icon(Icons.account_balance_wallet)),
          ],
        ),
      ),
      body: Column(
        children: [
          _OnlineToggle(isOnline: isOnline),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TasksTab(ref: ref),
                const _WalletTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated online/offline toggle with pulsing dot and gradient background.
class _OnlineToggle extends ConsumerStatefulWidget {
  const _OnlineToggle({required this.isOnline});

  final bool isOnline;

  @override
  ConsumerState<_OnlineToggle> createState() => _OnlineToggleState();
}

class _OnlineToggleState extends ConsumerState<_OnlineToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isOnline) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(_OnlineToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline && !oldWidget.isOnline) {
      _pulseController.repeat();
    } else if (!widget.isOnline && oldWidget.isOnline) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: widget.isOnline
            ? LinearGradient(
                colors: [AppTheme.emerald.withValues(alpha: 0.1), AppTheme.emerald.withValues(alpha: 0.05)],
              )
            : null,
        color: widget.isOnline ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          // Pulsing dot
          Stack(
            children: [
              if (widget.isOnline)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, _) {
                    final scale = 1.0 + 0.6 * _pulseController.value;
                    final opacity = 1.0 - _pulseController.value;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: opacity * 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: widget.isOnline ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: widget.isOnline ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.isOnline ? 'Online — Ready for rides' : 'Offline',
                key: ValueKey(widget.isOnline),
              ),
            ),
          ),
          const Spacer(),
          Switch(
            value: widget.isOnline,
            activeThumbColor: AppTheme.emerald,
            onChanged: (value) async {
              AppHaptics.selection();
              ref.read(driverOnlineStatusProvider.notifier).state = value;
              final api = ref.read(driverApiProvider);
              try {
                if (value) {
                  await api.goOnline();
                } else {
                  await api.goOffline();
                }
              } catch (_) {
                ref.read(driverOnlineStatusProvider.notifier).state = !value;
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final tasksAsync = widgetRef.watch(dispatchTaskStreamProvider);

    return tasksAsync.when(
      loading: () => _buildShimmerList(),
      error: (error, _) => _TasksFallback(ref: ref),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _TasksFallback(ref: ref);
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return FadeSlideIn(
              delay: Duration(milliseconds: index * 80),
              duration: const Duration(milliseconds: 350),
              child: DispatchTaskCard(
                task: task,
                onAccept: task.status == 'Available'
                    ? () => _acceptTask(context, task)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: const ShimmerCard(height: 120, borderRadius: 16),
      ),
    );
  }

  Future<void> _acceptTask(BuildContext context, DispatchTaskModel task) async {
    AppHaptics.medium();
    final api = ref.read(driverApiProvider);
    try {
      await api.acceptTask(task.id);
      ref.invalidate(dispatchTaskStreamProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept task: $e')),
        );
      }
    }
  }
}

class _TasksFallback extends ConsumerWidget {
  const _TasksFallback({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final mockAsync = widgetRef.watch(mockTaskProvider);

    return mockAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: const ShimmerCard(height: 120, borderRadius: 16),
        ),
      ),
      error: (_, _) => const EmptyState(
        icon: Icons.inbox,
        title: 'No tasks available',
        subtitle: 'Go online to receive ride offers',
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.inbox,
            title: 'No tasks available',
            subtitle: 'Go online to receive ride offers',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return FadeSlideIn(
              delay: Duration(milliseconds: index * 80),
              duration: const Duration(milliseconds: 350),
              child: DispatchTaskCard(
                task: task,
                onAccept: task.status == 'Available'
                    ? () => _acceptMockTask(context, task)
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  void _acceptMockTask(BuildContext context, DispatchTaskModel task) {
    AppHaptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Accepted ${task.taskType} task (demo)')),
    );
  }
}

class _WalletTab extends ConsumerWidget {
  const _WalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(driverWalletProvider);

    return walletAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: const ShimmerCard(height: 100, borderRadius: 16),
        ),
      ),
      error: (error, _) => _WalletFallback(),
      data: (wallet) => _WalletContent(
        balance: wallet.balance,
        entries: wallet.recentEntries,
        onWithdraw: () => _requestPayout(context, ref),
      ),
    );
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref) async {
    AppHaptics.medium();
    final api = ref.read(driverApiProvider);
    try {
      final result = await api.requestInstantPayout();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Payout of \u20B9${result.amount.toStringAsFixed(0)} processed (fee: \u20B9${result.fee.toStringAsFixed(0)})'
                  : result.message,
            ),
          ),
        );
      }
      ref.invalidate(driverWalletProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payout failed: $e')),
        );
      }
    }
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent({
    required this.balance,
    required this.entries,
    this.onWithdraw,
  });

  final double balance;
  final List<LedgerEntryModel> entries;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Animated balance card with gradient
        BounceIn(
          duration: const Duration(milliseconds: 600),
          child: AnimatedGradientHeader(
            colors: [AppTheme.emerald, AppTheme.emeraldDark],
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Current Balance',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 8),
                  CountUp(
                    target: balance,
                    prefix: '\u20B9',
                    decimals: 2,
                    duration: const Duration(milliseconds: 1500),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onWithdraw,
            icon: const Icon(Icons.flash_on),
            label: const Text('Instant Withdraw (\u20B95 Fee)'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Next Free Auto-Payout: Tuesday at 9 AM',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        ...entries.asMap().entries.map((entry) => SlideInLeft(
          delay: Duration(milliseconds: entry.key * 60),
          duration: const Duration(milliseconds: 300),
          child: _LedgerEntryTile(entry: entry.value),
        )),
      ],
    );
  }
}

class _LedgerEntryTile extends StatelessWidget {
  const _LedgerEntryTile({required this.entry});

  final LedgerEntryModel entry;

  @override
  Widget build(BuildContext context) {
    final isEarning = entry.amount > 0;
    return ListTile(
      leading: Icon(
        isEarning ? Icons.add_circle : Icons.remove_circle,
        color: isEarning ? AppTheme.emerald : AppTheme.danger,
      ),
      title: Text(entry.transactionType),
      subtitle: Text(entry.reference ?? ''),
      trailing: Text(
        '${isEarning ? '+' : ''}\u20B9${entry.amount.toStringAsFixed(2)}',
        style: TextStyle(
          color: isEarning ? AppTheme.emerald : AppTheme.danger,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WalletFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BounceIn(
          duration: const Duration(milliseconds: 600),
          child: AnimatedGradientHeader(
            colors: [AppTheme.emerald, AppTheme.emeraldDark],
            borderRadius: 20,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('Current Balance', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 8),
                  const CountUp(
                    target: 500,
                    prefix: '\u20B9',
                    suffix: '.00',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.flash_on),
            label: const Text('Instant Withdraw (\u20B95 Fee)'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Next Free Auto-Payout: Tuesday at 9 AM',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        SlideInLeft(child: ListTile(
          leading: Icon(Icons.add_circle, color: AppTheme.emerald),
          title: Text('Earning'),
          subtitle: Text('SEED-RIDE-001'),
          trailing: Text('\u20B9250.00', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600)),
        )),
        SlideInLeft(delay: const Duration(milliseconds: 80), child: ListTile(
          leading: Icon(Icons.add_circle, color: AppTheme.emerald),
          title: Text('Earning'),
          subtitle: Text('SEED-FOOD-001'),
          trailing: Text('\u20B9180.00', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600)),
        )),
        SlideInLeft(delay: const Duration(milliseconds: 160), child: ListTile(
          leading: Icon(Icons.add_circle, color: AppTheme.emerald),
          title: Text('Bonus'),
          subtitle: Text('SEED-LATE-NIGHT-BONUS'),
          trailing: Text('\u20B950.00', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w600)),
        )),
      ],
    );
  }
}

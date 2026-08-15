import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineStatusProvider);

    return Column(
      children: [
        _OnlineToggle(isOnline: isOnline),
        Expanded(
          child: _TasksTab(ref: ref, isOnline: isOnline),
        ),
      ],
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
  const _TasksTab({required this.ref, required this.isOnline});

  final WidgetRef ref;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    // When offline, hide all task cards and show an offline message.
    if (!isOnline) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_bolt, size: 64, color: AppTheme.slate.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'You are offline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go online to receive ride and delivery offers',
                style: TextStyle(color: AppTheme.slate.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
                onAccept: task.status == 'Available' &&
                        isOnline &&
                        ref.read(activeTaskProvider) == null
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
      final accepted = await api.acceptTask(task.id);
      ref.invalidate(dispatchTaskStreamProvider);
      ref.read(activeTaskProvider.notifier).state = accepted;
      ref.read(driverSelectedTabProvider.notifier).state = 1;
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
    ref.read(activeTaskProvider.notifier).state = task;
    ref.read(driverSelectedTabProvider.notifier).state = 1;
  }
}



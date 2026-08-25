import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/animations/haptic.dart';
import '../../core/animations/staggered_animations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../auth/application/auth_controller.dart';

/// A clean Apple-style grouped list of secondary services accessible from the
/// "More" tab. Replaces the old multi-colored Windows 8-style grid.
class ServicesHubScreen extends ConsumerWidget {
  const ServicesHubScreen({super.key});

  static const _services = [
    _HubService(
      icon: Icons.receipt_long_outlined,
      title: 'My Bookings & Activity',
      subtitle: 'Stays, food, rides, rentals',
      route: '/activity',
    ),
    _HubService(
      icon: Icons.bookmark_outline,
      title: 'Saved Places & Addresses',
      subtitle: 'Your go-to locations',
      route: '/rides/saved-locations',
    ),
    _HubService(
      icon: Icons.restaurant_outlined,
      title: 'Dietary Preferences',
      subtitle: 'No Preference, Veg, Non-Veg, Vegan',
      route: '__dietary__',
    ),
    _HubService(
      icon: Icons.palette_outlined,
      title: 'App Theme',
      subtitle: 'System, Light, Dark',
      route: '__theme__',
    ),
    _HubService(
      icon: Icons.emergency_outlined,
      title: 'Safety & Emergency SOS',
      subtitle: 'Contacts and emergency settings',
      route: '/rides/emergency-contacts',
    ),
    _HubService(
      icon: Icons.headset_mic_outlined,
      title: 'Help & Support',
      subtitle: 'Disputes, help, contact us',
      route: '/help',
    ),
    _HubService(
      icon: Icons.shopping_bag_outlined,
      title: 'Quick Essentials',
      subtitle: 'Essentials & daily needs',
      route: '/essentials',
    ),
    _HubService(
      icon: Icons.auto_awesome,
      title: 'Genie Errand Service',
      subtitle: 'Custom errands — type anything you need',
      route: '/genie',
    ),
    _HubService(
      icon: Icons.group,
      title: 'Split Payment',
      subtitle: 'Share costs with friends via WhatsApp',
      route: '/split-payment',
    ),
    _HubService(
      icon: Icons.museum_outlined,
      title: 'Explore',
      subtitle: 'Experiences & safety tips',
      route: '/experiences',
    ),
    _HubService(
      icon: Icons.person_outline,
      title: 'Profile',
      subtitle: 'Account, themes & settings',
      route: '/profile',
    ),
    _HubService(
      icon: Icons.logout,
      title: 'Sign Out',
      subtitle: 'Log out of your account',
      route: '__signout__',
    ),
  ];

  Future<void> _showDietaryDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('dietary_preference') ?? 'No Preference';
    final options = ['No Preference', 'Vegetarian', 'Non-Veg', 'Vegan'];

    if (!context.mounted) return;

    String? selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempSelection = current;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Dietary Preferences'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                return RadioListTile<String>(
                  value: opt,
                  groupValue: tempSelection,
                  title: Text(opt),
                  activeColor: AppTheme.emerald,
                  onChanged: (v) => setState(() => tempSelection = v ?? current),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, tempSelection),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != current) {
      await prefs.setString('dietary_preference', selected);
      if (context.mounted) {
        AppHaptics.light();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dietary preference set to $selected')),
        );
      }
    }
  }

  Future<void> _showThemeDialog(BuildContext context, WidgetRef ref) async {
    final currentMode = ref.read(themeControllerProvider);
    final options = {
      ThemeModePreference.system: 'System',
      ThemeModePreference.light: 'Light',
      ThemeModePreference.dark: 'Dark',
    };

    if (!context.mounted) return;

    ThemeModePreference? selected = await showDialog<ThemeModePreference>(
      context: context,
      builder: (ctx) {
        ThemeModePreference tempSelection = currentMode;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('App Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.entries.map((e) {
                return RadioListTile<ThemeModePreference>(
                  value: e.key,
                  groupValue: tempSelection,
                  title: Text(e.value),
                  activeColor: AppTheme.emerald,
                  onChanged: (v) => setState(() => tempSelection = v ?? currentMode),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, tempSelection),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentMode) {
      await ref.read(themeControllerProvider.notifier).setMode(selected);
      if (context.mounted) {
        AppHaptics.light();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Theme set to ${options[selected]}')),
        );
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      AppHaptics.light();
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Services'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return FadeSlideIn(
            delay: Duration(milliseconds: index * 60),
            child: _HubRow(
              service: service,
              isFirst: index == 0,
              isLast: index == _services.length - 1,
              isDark: isDark,
              onTap: () {
                AppHaptics.light();
                if (service.route == '__dietary__') {
                  _showDietaryDialog(context);
                } else if (service.route == '__theme__') {
                  _showThemeDialog(context, ref);
                } else if (service.route == '__signout__') {
                  _confirmSignOut(context, ref);
                } else if (service.route.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support chat is coming soon.')),
                  );
                } else {
                  context.push(service.route);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _HubService {
  const _HubService({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.service,
    required this.isFirst,
    required this.isLast,
    required this.isDark,
    required this.onTap,
  });

  final _HubService service;
  final bool isFirst;
  final bool isLast;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.white,
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(AppRadius.lg) : Radius.zero,
            topRight: isFirst ? const Radius.circular(AppRadius.lg) : Radius.zero,
            bottomLeft: isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
          ),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      service.icon,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          service.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.slate,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 16,
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
              ),
          ],
        ),
      ),
    );
  }
}

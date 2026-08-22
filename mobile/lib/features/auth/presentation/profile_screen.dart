import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../application/auth_controller.dart';
import 'delete_account_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final themeMode = ref.watch(themeControllerProvider);
    final dietaryPref = ref.watch(_dietaryPreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar with scale-in
                ScaleFadeIn(
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.emeraldGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session?.name.isNotEmpty == true ? session!.name : 'Guest',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  session?.phone.isNotEmpty == true ? '+91 ${session!.phone}' : 'Not signed in',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          session?.role ?? 'tourist',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (session?.isProMember == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warning,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- Appearance section ---
                _SectionHeader(title: 'Appearance'),
                const SizedBox(height: 8),
                _ThemeModeSelector(
                  currentMode: themeMode,
                  onChanged: (mode) {
                    AppHaptics.selection();
                    ref.read(themeControllerProvider.notifier).setMode(mode);
                  },
                ),
                const SizedBox(height: 24),

                // --- Dietary preference section ---
                if (session?.isAuthenticated == true) ...[
                  _SectionHeader(title: 'Dietary Preference'),
                  const SizedBox(height: 8),
                  _DietaryPreferenceSelector(
                    currentPreference: dietaryPref,
                    onChanged: (pref) async {
                      AppHaptics.selection();
                      try {
                        await ref.read(apiClientProvider).put(
                          '/api/user/dietary-preference',
                          data: {'preference': pref},
                        );
                        ref.read(_dietaryPreferenceProvider.notifier).state =
                            pref;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not save preference. Please try again.')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // --- History section ---
                if (session?.isAuthenticated == true) ...[
                  _SectionHeader(title: 'Your Activity'),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    child: _HistoryLink(
                      icon: Icons.restaurant,
                      title: 'Food Orders',
                      subtitle: 'View your food delivery history',
                      onTap: () {
                        AppHaptics.light();
                        context.push('/food/orders');
                      },
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _HistoryLink(
                      icon: Icons.shopping_bag,
                      title: 'Essentials Orders',
                      subtitle: 'View your essentials order history',
                      onTap: () {
                        AppHaptics.light();
                        context.push('/essentials/orders');
                      },
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _HistoryLink(
                      icon: Icons.directions_car,
                      title: 'Ride History',
                      subtitle: 'View your ride history',
                      onTap: () {
                        AppHaptics.light();
                        context.push('/rides/history');
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    child: _HistoryLink(
                      icon: Icons.phone_android_outlined,
                      title: 'Change Phone Number',
                      subtitle: 'Verify a new number via OTP',
                      onTap: () {
                        AppHaptics.light();
                        context.push('/change-phone');
                      },
                    ),
                  ),
                  const Divider(height: 32),
                  // Right to be Forgotten: Delete Account & Data
                  // Highly visible red button in the main Profile Settings view.
                  // Opens a severe bottom sheet requiring the user to type
                  // "DELETE" to confirm, preventing accidental data destruction.
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                    onPressed: () => DeleteAccountSheet.show(context, ref),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account & Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.coral,
                      side: BorderSide(color: AppTheme.coral.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                    onPressed: () {
                      AppHaptics.medium();
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  _SectionHeader(title: 'Getting Started'),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    child: _HistoryLink(
                      icon: Icons.login,
                      title: 'Sign In',
                      subtitle: 'Access your orders, rides, and bookings',
                      onTap: () {
                        AppHaptics.light();
                        context.go('/auth');
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeModePreference currentMode;
  final ValueChanged<ThemeModePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _modeChip(
            context,
            icon: Icons.brightness_auto,
            label: 'System',
            selected: currentMode == ThemeModePreference.system,
            onTap: () => onChanged(ThemeModePreference.system),
          ),
          _modeChip(
            context,
            icon: Icons.light_mode,
            label: 'Light',
            selected: currentMode == ThemeModePreference.light,
            onTap: () => onChanged(ThemeModePreference.light),
          ),
          _modeChip(
            context,
            icon: Icons.dark_mode,
            label: 'Dark',
            selected: currentMode == ThemeModePreference.dark,
            onTap: () => onChanged(ThemeModePreference.dark),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.emerald, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Dietary preference state and widget ---

final _dietaryPreferenceProvider = StateProvider<String?>((ref) => null);

class _DietaryPreferenceSelector extends StatelessWidget {
  const _DietaryPreferenceSelector({
    required this.currentPreference,
    required this.onChanged,
  });

  final String? currentPreference;
  final Function(String?) onChanged;

  static const _options = [
    (null, 'No Preference', Icons.shuffle),
    ('veg', 'Vegetarian', Icons.eco_outlined),
    ('non_veg', 'Non-Veg', Icons.restaurant_outlined),
    ('vegan', 'Vegan', Icons.spa_outlined),
    ('egg', 'Eggetarian', Icons.egg_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = currentPreference == value;
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onChanged(value),
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
          checkmarkColor: AppTheme.emerald,
          side: BorderSide(
            color: isSelected
                ? AppTheme.emerald
                : Theme.of(context).dividerColor,
          ),
        );
      }).toList(),
    );
  }
}

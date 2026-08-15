import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// First-launch onboarding screen for consumers.
///
/// 3-step flow shown after first login:
/// 1. Welcome animation + dietary preference selection
/// 2. Set Home location
/// 3. Set Work location (optional)
///
/// On completion, calls the backend to mark onboarding as complete.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isSubmitting = false;

  String? _dietaryPreference;

  static const _dietaryOptions = [
    ('veg', 'Vegetarian', Icons.eco_outlined, Color(0xFF22C55E)),
    ('non_veg', 'Non-Vegetarian', Icons.restaurant_outlined, Color(0xFFEF4444)),
    ('vegan', 'Vegan', Icons.spa_outlined, Color(0xFF10B981)),
    ('egg', 'Eggetarian', Icons.egg_outlined, Color(0xFFF59E0B)),
    (null, 'No Preference', Icons.shuffle, Color(0xFF6B7280)),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      AppHaptics.light();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      AppHaptics.light();
    }
  }

  Future<void> _finish() async {
    setState(() => _isSubmitting = true);
    AppHaptics.medium();

    try {
      final api = ref.read(apiClientProvider);

      // Save dietary preference
      if (_dietaryPreference != null) {
        await api.put('/api/user/dietary-preference', data: {
          'preference': _dietaryPreference,
        });
      }

      // Mark onboarding complete
      await api.post('/api/user/complete-onboarding');

      if (mounted) {
        AppHaptics.success();
        context.go('/');
      }
    } on Exception catch (_) {
      // Non-fatal — user can still use the app
      if (mounted) {
        AppHaptics.success();
        context.go('/');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to PondyConnect'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
        actions: [
          TextButton(
            onPressed: () {
              AppHaptics.light();
              _finish();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.lagoon),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildDietaryStep(),
                _buildLocationStep('Home', Icons.home_outlined),
                _buildLocationStep('Work', Icons.work_outlined, isOptional: true),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_currentPage < 2)
                    FilledButton(
                      onPressed: _nextPage,
                      child: const Text('Continue'),
                    )
                  else
                    FilledButton(
                      onPressed: _isSubmitting ? null : _finish,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Get Started'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lagoon.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu,
                size: 48, color: AppTheme.lagoon),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'What\'s your diet?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We\'ll personalize restaurant recommendations for you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ..._dietaryOptions.map((option) {
            final (value, label, icon, color) = option;
            final isSelected = _dietaryPreference == value ||
                (_dietaryPreference == null && value == null);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DietaryOption(
                label: label,
                icon: icon,
                color: color,
                isSelected: isSelected,
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _dietaryPreference = value);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLocationStep(String label, IconData icon,
      {bool isOptional = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lagoon.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppTheme.lagoon),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Set your $label location',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isOptional
                ? 'Optional — but it makes booking rides faster'
                : 'We\'ll use this to suggest quick ride destinations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () {
              AppHaptics.light();
              // Navigate to saved locations screen to add a location
              context.go('/saved-locations?label=${label.toLowerCase()}');
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text('Add $label Location'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            ),
          ),
          if (isOptional) ...[
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () {
                AppHaptics.light();
                _finish();
              },
              child: const Text('Skip for now'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DietaryOption extends StatelessWidget {
  const _DietaryOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Theme.of(context).dividerColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withValues(alpha: 0.05) : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

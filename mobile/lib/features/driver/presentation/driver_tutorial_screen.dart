import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/driver_providers.dart';

/// Mandatory safety tutorial screen for drivers.
///
/// A swipeable 5-page tutorial covering platform rules, safety guidelines,
/// payout structures, and ride acceptance policies. The driver must complete
/// the tutorial and sign a digital agreement before they can accept rides.
class DriverTutorialScreen extends ConsumerStatefulWidget {
  const DriverTutorialScreen({super.key});

  @override
  ConsumerState<DriverTutorialScreen> createState() =>
      _DriverTutorialScreenState();
}

class _DriverTutorialScreenState extends ConsumerState<DriverTutorialScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _hasAgreed = false;
  bool _isSubmitting = false;

  static const _pages = [
    _TutorialPage(
      icon: Icons.waving_hand_outlined,
      title: 'Welcome, Captain!',
      subtitle: 'You\'re about to join PondyConnect',
      points: [
        'PondyConnect is Pondicherry\'s local ride-hailing platform',
        'We connect tourists and locals with reliable drivers',
        'You set your own hours — drive whenever you want',
        'No commission deducted from your earnings',
      ],
      color: AppTheme.info,
    ),
    _TutorialPage(
      icon: Icons.security_outlined,
      title: 'Safety First',
      subtitle: 'Guidelines to keep everyone safe',
      points: [
        'Always verify the rider\'s OTP before starting the ride',
        'Follow traffic rules and speed limits at all times',
        'Use the in-app SOS button if you feel unsafe',
        'Never share your login credentials with anyone',
        'Report any incidents through the app immediately',
      ],
      color: AppTheme.danger,
    ),
    _TutorialPage(
      icon: Icons.payments_outlined,
      title: 'Earnings & Payouts',
      subtitle: 'Transparent earnings, no hidden fees',
      points: [
        '0% commission — you keep 100% of your earnings',
        'Fares are calculated transparently in the app',
        'Instant payouts to your UPI ID available',
        'Weekly earnings summary in the Earnings tab',
        'Tips from riders go directly to you',
      ],
      color: AppTheme.success,
    ),
    _TutorialPage(
      icon: Icons.rule_outlined,
      title: 'Ride Policies',
      subtitle: 'Acceptance and cancellation rules',
      points: [
        'Accept rides promptly — high acceptance rate improves your ranking',
        'If you must cancel, do so before reaching the pickup',
        'Arrive at pickup within the estimated time',
        'Be polite and professional with all riders',
        'Rate riders after each trip to maintain quality',
      ],
      color: AppTheme.lagoon,
    ),
    _TutorialPage(
      icon: Icons.assignment_outlined,
      title: 'Agreement',
      subtitle: 'Sign to start accepting rides',
      points: [
        'I agree to follow all safety guidelines',
        'I will maintain valid documents (DL, RC, Insurance)',
        'I understand fraudulent activity leads to permanent ban',
        'I consent to location tracking during active rides',
      ],
      color: AppTheme.warning,
      isAgreementPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
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

  Future<void> _completeTutorial() async {
    if (!_hasAgreed) {
      AppToast.show(context, 'Please agree to the terms to continue',
          type: ToastType.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.medium();

    try {
      final api = ref.read(driverApiProvider);
      await api.signAgreement();
      await api.completeTutorial();

      if (mounted) {
        AppHaptics.success();
        AppToast.show(context, 'Tutorial completed! You can now go online.',
            type: ToastType.success);
        context.go('/');
      }
    } on Exception catch (e) {
      if (mounted) {
        AppHaptics.error();
        AppToast.show(context, _friendlyError(e.toString()),
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('DioException') || raw.contains('Socket')) {
      return 'Could not reach the server. Please check your connection.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Tutorial'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppHaptics.light();
            if (_currentPage > 0) {
              _previousPage();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / _pages.length,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              _pages[_currentPage].color,
            ),
          ),
          // Page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                final page = _pages[i];
                return _buildPage(page, i);
              },
            ),
          ),
          // Bottom controls
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
                  if (_currentPage < _pages.length - 1)
                    FilledButton(
                      onPressed: _nextPage,
                      child: const Text('Next'),
                    )
                  else
                    FilledButton(
                      onPressed: _isSubmitting ? null : _completeTutorial,
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _pages[_currentPage].color),
                            )
                          : const Text('I Agree — Start Driving'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_TutorialPage page, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            page.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ...page.points.map((point) => _buildPoint(point, page.color)),
          if (page.isAgreementPage) ...[
            const SizedBox(height: AppSpacing.lg),
            CheckboxListTile(
              value: _hasAgreed,
              onChanged: (v) {
                AppHaptics.selection();
                setState(() => _hasAgreed = v ?? false);
              },
              title: const Text(
                'I have read and agree to all terms',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              activeColor: page.color,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.color,
    this.isAgreementPage = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> points;
  final Color color;
  final bool isAgreementPage;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Driver-side ride rating screen.
/// Lets the captain rate the rider after completing a trip.
class DriverRideRatingScreen extends ConsumerStatefulWidget {
  const DriverRideRatingScreen({super.key, required this.rideId, required this.riderName});

  final String rideId;
  final String riderName;

  @override
  ConsumerState<DriverRideRatingScreen> createState() =>
      _DriverRideRatingScreenState();
}

class _DriverRideRatingScreenState extends ConsumerState<DriverRideRatingScreen> {
  int _rating = 0;
  final _feedbackController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  static const _feedbackTags = [
    'Polite', 'On time for pickup', 'Clear directions', 'Patient', 'Respectful', 'Good tipper',
  ];
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    AppHaptics.success();
    setState(() => _submitting = true);
    try {
      final api = ref.read(ridesApiProvider);
      final feedback = _selectedTags.isEmpty
          ? _feedbackController.text.trim()
          : '${_selectedTags.join(', ')}. ${_feedbackController.text.trim()}'.trim();
      await api.rateRide(widget.rideId, _rating, feedback: feedback.isEmpty ? null : feedback, byDriver: true);
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Rider')),
      body: _submitted ? _buildThankYou() : _buildRatingForm(),
    );
  }

  Widget _buildRatingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.emerald, AppTheme.emeraldLight]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'How was ${widget.riderName}?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us improve the platform',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: () {
                  AppHaptics.light();
                  setState(() => _rating = star);
                },
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 48,
                  color: star <= _rating ? AppTheme.gold : AppTheme.slate.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          // Feedback tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feedbackTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (_) {
                  AppHaptics.light();
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.emerald,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _feedbackController,
            decoration: const InputDecoration(
              labelText: 'Additional comments (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.comment_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _submitting ? null : _submitRating,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.emerald,
            ),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Rating', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.emerald, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Thank you!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Your rating has been submitted',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => context.go('/'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor: AppTheme.emerald,
              ),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

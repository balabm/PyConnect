import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class RideRatingScreen extends ConsumerStatefulWidget {
  const RideRatingScreen({super.key, required this.rideId, required this.driverName});
  final String rideId;
  final String driverName;

  @override
  ConsumerState<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends ConsumerState<RideRatingScreen> {
  int _rating = 0;
  int _tipAmount = 0;
  final _feedbackController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  static const _tipOptions = [0, 10, 20, 30, 50];
  static const _feedbackTags = [
    'Safe driving', 'Friendly', 'On time', 'Clean vehicle', 'Knows the route', 'Professional',
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
      await api.rateRide(widget.rideId, _rating, feedback: feedback.isEmpty ? null : feedback);
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
      appBar: AppBar(
        title: const Text('Rate Your Ride'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: _submitted ? _buildThankYou(context) : _buildRatingForm(context),
    );
  }

  Widget _buildRatingForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(widget.driverName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('How was your ride?', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15)),
          const SizedBox(height: 24),
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              return GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  setState(() => _rating = starValue);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    size: 48,
                    color: starValue <= _rating ? AppTheme.warning : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _ratingLabel(_rating),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 32),
          // Quick feedback tags
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('What went well?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _feedbackTags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: selected,
                onSelected: (val) {
                  AppHaptics.light();
                  setState(() {
                    if (val) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Feedback text
          TextField(
            controller: _feedbackController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional comments (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          // Tip
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Tip your driver (100% goes to driver)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Show appreciation for great service', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Row(
            children: _tipOptions.map((amount) {
              final selected = _tipAmount == amount;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _tipAmount = amount);
                    },
                    child: Card(
                      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            amount == 0 ? 'None' : '\u20B9$amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selected ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submitRating,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Rating'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting ? null : () => context.pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleFadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.lagoon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppTheme.lagoon, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Thank You!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps improve rides for everyone',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (_tipAmount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  '\u20B9$_tipAmount tip will be added to your ride',
                  style: const TextStyle(color: AppTheme.lagoon, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    AppHaptics.light();
                    context.pop();
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Tap to rate';
    }
  }
}

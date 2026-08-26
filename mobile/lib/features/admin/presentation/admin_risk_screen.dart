import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_api.dart';

/// Admin risk management screen.
/// Lets admins look up a user's trust score, override it, and apply
/// penalties or rewards.
class AdminRiskScreen extends ConsumerStatefulWidget {
  const AdminRiskScreen({super.key});

  @override
  ConsumerState<AdminRiskScreen> createState() => _AdminRiskScreenState();
}

class _AdminRiskScreenState extends ConsumerState<AdminRiskScreen> {
  final _userIdController = TextEditingController();
  final _scoreController = TextEditingController();
  AdminRiskScore? _riskScore;
  bool _loading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) return;
    AppHaptics.light();
    setState(() => _loading = true);
    try {
      final score = await ref.read(adminApiProvider).getRiskScore(userId);
      if (mounted) {
        setState(() {
          _riskScore = score;
          if (score != null) _scoreController.text = score.trustScore.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lookup failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setScore() async {
    final userId = _userIdController.text.trim();
    final score = int.tryParse(_scoreController.text.trim());
    if (userId.isEmpty || score == null) return;
    AppHaptics.light();
    try {
      await ref.read(adminApiProvider).setTrustScore(userId, score);
      await _lookup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trust score updated'), backgroundColor: AppTheme.emerald),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _applyPenalty(String type) async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) return;
    AppHaptics.warning();
    try {
      final api = ref.read(adminApiProvider);
      if (type == 'refund') {
        await api.applyRefundPenalty(userId);
      } else if (type == 'cancellation') {
        await api.applyCancellationPenalty(userId);
      } else if (type == 'fivestar') {
        await api.awardFiveStar(userId);
      }
      await _lookup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'fivestar' ? 'Reward applied' : 'Penalty applied'),
            backgroundColor: type == 'fivestar' ? AppTheme.emerald : AppTheme.gold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Risk Management')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User lookup
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'Enter user GUID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _lookup,
              icon: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('Look Up Risk Score'),
            ),
            const SizedBox(height: 24),
            // Risk score card
            if (_riskScore != null) ...[
              _RiskScoreCard(score: _riskScore!),
              const SizedBox(height: 20),
              // Override score
              TextField(
                controller: _scoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Override Trust Score (0-100)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _setScore,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.emerald),
                child: const Text('Set Trust Score'),
              ),
              const SizedBox(height: 24),
              // Penalty / reward actions
              Text('Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Refund Penalty'),
                    avatar: const Icon(Icons.remove_circle, color: AppTheme.danger),
                    onPressed: () => _applyPenalty('refund'),
                  ),
                  ActionChip(
                    label: const Text('Cancellation Penalty'),
                    avatar: const Icon(Icons.cancel, color: AppTheme.danger),
                    onPressed: () => _applyPenalty('cancellation'),
                  ),
                  ActionChip(
                    label: const Text('5-Star Reward'),
                    avatar: const Icon(Icons.star, color: AppTheme.gold),
                    onPressed: () => _applyPenalty('fivestar'),
                  ),
                ],
              ),
            ] else if (!_loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: AppTheme.slate.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'Enter a user ID to view their risk profile',
                        style: TextStyle(color: AppTheme.slate.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RiskScoreCard extends StatelessWidget {
  const _RiskScoreCard({required this.score});
  final AdminRiskScore score;

  @override
  Widget build(BuildContext context) {
    final scoreColor = score.trustScore >= 70
        ? AppTheme.emerald
        : score.trustScore >= 40
            ? AppTheme.gold
            : AppTheme.danger;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trust Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '${score.trustScore}/100',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scoreColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: score.trustScore / 100,
              backgroundColor: AppTheme.slate.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(scoreColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            _StatusRow(label: 'COD Disabled', value: score.isCodDisabled, icon: Icons.block),
            _StatusRow(label: 'Shadow Banned', value: score.isShadowBanned, icon: Icons.visibility_off),
            if (score.trustScoreUpdatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Updated: ${score.trustScoreUpdatedAt}',
                  style: TextStyle(fontSize: 11, color: AppTheme.slate.withValues(alpha: 0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, required this.icon});
  final String label;
  final bool value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? AppTheme.danger : AppTheme.emerald),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value ? 'Yes' : 'No',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value ? AppTheme.danger : AppTheme.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

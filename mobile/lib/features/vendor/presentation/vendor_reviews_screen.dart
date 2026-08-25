import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/design/design.dart';
import '../application/vendor_providers.dart';

/// Vendor Reviews screen — shows the venue's rating summary and a list of
/// customer reviews. The venue owner can publicly reply to each review.
class VendorReviewsScreen extends ConsumerStatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  ConsumerState<VendorReviewsScreen> createState() =>
      _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends ConsumerState<VendorReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final reviews = await api.getReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0.0;
    var sum = 0.0;
    for (final r in _reviews) {
      sum += (r['rating'] as num?)?.toDouble() ?? 0.0;
    }
    return sum / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () {
              AppHaptics.light();
              _loadReviews();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.emerald),
      );
    }
    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadReviews,
      );
    }
    if (_reviews.isEmpty) {
      return EmptyState(
        icon: Icons.reviews_outlined,
        title: 'No reviews yet',
        subtitle: 'Customer reviews will appear here once they start rolling in',
      );
    }

    return RefreshIndicator(
      color: AppTheme.emerald,
      onRefresh: _loadReviews,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _RatingSummaryCard(
            average: _averageRating,
            count: _reviews.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._reviews.map((r) => _ReviewCard(
                review: r,
                onReplyPosted: _loadReviews,
              )),
        ],
      ),
    );
  }
}

/// Top summary card showing the big average rating, a row of 5 stars, and
/// the total review count.
class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ratingText = average.toStringAsFixed(1);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.star_rounded,
                  size: 40, color: AppTheme.warning),
              const SizedBox(width: AppSpacing.sm),
              Text(
                ratingText,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ 5.0',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StarsRow(rating: average, size: 18),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Based on $count review${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A single review card with reviewer info, star rating, feedback text,
/// date, and either an existing owner reply or a reply input.
class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.review, required this.onReplyPosted});

  final Map<String, dynamic> review;
  final VoidCallback onReplyPosted;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  final _replyController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String? get _ownerReply => widget.review['ownerReply'] as String?;
  String? get _ownerReplyedAt =>
      widget.review['ownerReplyedAt'] as String? ??
      widget.review['ownerRepliedAt'] as String?;

  Future<void> _postReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;

    AppHaptics.light();
    setState(() => _isPosting = true);
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final reviewId = widget.review['id']?.toString() ?? '';
      await api.replyToReview(reviewId, reply);
      if (!mounted) return;
      _replyController.clear();
      AppHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply posted'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onReplyPosted();
    } catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post reply: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final name = (review['reviewerName'] as String?) ?? 'Anonymous';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final feedback = (review['feedback'] as String?) ?? '';
    final createdAt = (review['createdAt'] as String?) ?? '';
    final hasReply = _ownerReply != null && _ownerReply!.isNotEmpty;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer header
          Row(
            children: [
              _Avatar(initials: _initials(name)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _StarsRow(rating: rating, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Feedback text
          Text(
            feedback,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          // Owner reply or input
          if (hasReply)
            _OwnerReplyBox(
              reply: _ownerReply!,
              date: _formatDate(_ownerReplyedAt ?? ''),
            )
          else
            _ReplyInput(
              controller: _replyController,
              isPosting: _isPosting,
              onPost: _postReply,
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

/// Circular avatar showing the reviewer's initials.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppTheme.emerald,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// A row of 5 star icons visually representing the given rating.
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.rating, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 2 : 0),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? AppTheme.warning : AppTheme.warning.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

/// Highlighted box showing an existing owner reply.
class _OwnerReplyBox extends StatelessWidget {
  const _OwnerReplyBox({required this.reply, required this.date});

  final String reply;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(color: AppTheme.emerald, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined,
                  size: 14, color: AppTheme.emerald),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Owner Reply',
                style: TextStyle(
                  color: AppTheme.emerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (date.isNotEmpty)
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reply,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Reply input with a text field and a "Post Reply" button.
class _ReplyInput extends StatelessWidget {
  const _ReplyInput({
    required this.controller,
    required this.isPosting,
    required this.onPost,
  });

  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Type your reply as Venue Owner...',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isPosting ? null : onPost,
            icon: isPosting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(isPosting ? 'Posting...' : 'Post Reply'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

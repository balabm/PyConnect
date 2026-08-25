import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loaders.dart';
import '../services/ticket_cache.dart';

/// Displays the user's event tickets.
///
/// Cached tickets are rendered instantly from [TicketCache] on init, then a
/// background sync fetches the authoritative list from the server. While the
/// cache is being shown a subtle "Offline cached" badge is displayed; once the
/// server response arrives the list is replaced and the fresh tickets are
/// persisted back to the cache for next launch.
class TicketWalletScreen extends ConsumerStatefulWidget {
  const TicketWalletScreen({super.key});

  @override
  ConsumerState<TicketWalletScreen> createState() =>
      _TicketWalletScreenState();
}

class _TicketWalletScreenState extends ConsumerState<TicketWalletScreen> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Load cached tickets instantly.
    final cached = await ref.read(ticketCacheProvider).loadTickets();
    if (!mounted) return;
    setState(() {
      _tickets = cached;
      _loading = cached.isEmpty;
    });

    // 2. Sync with server in the background.
    await _syncFromServer();
  }

  Future<void> _syncFromServer() async {
    if (!mounted) return;
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final body = await api.get('/api/p2p-events/my-tickets');
      final list = (body as List?) ?? const [];
      final serverTickets =
          list.cast<Map<String, dynamic>>().toList();

      if (!mounted) return;

      // Persist fresh tickets to cache.
      final cache = ref.read(ticketCacheProvider);
      for (final t in serverTickets) {
        await cache.saveTicket(t);
      }

      setState(() {
        _tickets = serverTickets;
        _loading = false;
        _syncing = false;
      });
      AppHaptics.success();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        // Keep showing cached tickets if we have them.
        _error = _tickets.isEmpty ? e.toString() : null;
      });
      if (_tickets.isEmpty) AppHaptics.warning();
    }
  }

  Future<void> _onRefresh() async {
    AppHaptics.light();
    await _syncFromServer();
  }

  @override
  Widget build(BuildContext context) {
    // While there are no cached tickets and we're still loading, show skeleton.
    if (_loading && _tickets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Tickets')),
        body: const SkeletonList(type: SkeletonType.booking, count: 4),
      );
    }

    // No cache and a hard error — show the error state with retry.
    if (_error != null && _tickets.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Tickets')),
        body: ErrorState(message: _error!, onRetry: _syncFromServer),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _tickets.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      icon: Icons.confirmation_number_outlined,
                      title: 'No tickets yet',
                      subtitle: 'Book your next night out!',
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  // Inline error banner (cached tickets still visible below).
                  if (_error != null)
                    _SyncErrorBanner(onRetry: _syncFromServer),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: _tickets.length,
                      itemBuilder: (ctx, i) {
                        final ticket = _tickets[i];
                        final isCached = _syncing && ticket['__cached'] == true;
                        return _TicketCard(
                          ticket: ticket,
                          showOfflineBadge: isCached,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A compact banner shown above cached tickets when the background sync fails.
class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: AppTheme.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Showing offline tickets. Pull to refresh.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single ticket card with an expandable QR code.
class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.ticket, this.showOfflineBadge = false});
  final Map<String, dynamic> ticket;
  final bool showOfflineBadge;

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  double? _originalBrightness;
  final ScreenBrightness _brightness = ScreenBrightness();

  void _toggleQr() {
    AppHaptics.light();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _maximizeBrightness();
    } else {
      _restoreBrightness();
    }
  }

  /// Forces the screen to 100% brightness so the bouncer's scanner can
  /// read the QR code instantly, even in a dark nightclub doorway.
  Future<void> _maximizeBrightness() async {
    try {
      _originalBrightness = await _brightness.application;
      await _brightness.setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Brightness control may not be available on all platforms.
    }
  }

  /// Restores the screen brightness to the user's previous setting.
  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await _brightness.setApplicationScreenBrightness(_originalBrightness!);
      } else {
        await _brightness.resetApplicationScreenBrightness();
      }
    } catch (_) {
      // Ignore — best-effort restore.
    }
  }

  @override
  void dispose() {
    if (_expanded) {
      _restoreBrightness();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final eventName = (t['eventName'] as String?) ?? 'Untitled Event';
    final eventDate = t['eventDate'] as String? ?? '';
    final venue = (t['venueName'] as String?) ?? 'Venue TBA';
    final ticketType = (t['ticketType'] as String?) ?? 'General';
    final qrPayload = (t['qrPayload'] as String?) ?? '';
    final orderId = (t['orderId'] as String?) ?? '';
    final status = (t['status'] as String?) ?? 'Active';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: event name + offline badge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  eventName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.showOfflineBadge) _offlineBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Date & venue.
          _infoRow(Icons.event_outlined, _formatDate(eventDate)),
          const SizedBox(height: 4),
          _infoRow(Icons.location_on_outlined, venue),
          const SizedBox(height: AppSpacing.md),

          // Ticket type + status chips.
          Row(
            children: [
              _chip(
                ticketType,
                AppTheme.emerald.withValues(alpha: 0.12),
                AppTheme.emerald,
              ),
              const SizedBox(width: AppSpacing.sm),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // QR toggle row.
          InkWell(
            onTap: _toggleQr,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 22,
                    color: AppTheme.charcoal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _expanded ? 'Hide QR code' : 'Show QR code',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.slate,
                  ),
                ],
              ),
            ),
          ),

          // Expandable QR code.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Center(
                      child: qrPayload.isEmpty
                          ? Text(
                              'QR code unavailable',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.slate,
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 220,
                                gapless: true,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Order ID footer.
          if (orderId.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(
              height: 1,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Order ID: $orderId',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.slate,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.slate),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final isActive =
        status.toLowerCase() == 'active' || status.toLowerCase() == 'valid';
    final isCancelled = status.toLowerCase() == 'cancelled';
    final color = isActive
        ? AppTheme.emerald
        : isCancelled
            ? AppTheme.danger
            : AppTheme.warning;
    return _chip(status, color.withValues(alpha: 0.12), color);
  }

  Widget _offlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.slate.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 11, color: AppTheme.slate),
          const SizedBox(width: 3),
          Text(
            'Offline cached',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso.isEmpty ? 'Date TBA' : iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

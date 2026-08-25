import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

class AdminTicketsScreen extends ConsumerStatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  ConsumerState<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends ConsumerState<AdminTicketsScreen> {
  String? _statusFilter;
  int _page = 1;
  static const _pageSize = 50;

  static const _statusOptions = [null, 'Open', 'InProgress', 'Escalated', 'Resolved'];

  @override
  Widget build(BuildContext context) {
    final params = AdminTicketParams(status: _statusFilter, page: _page, pageSize: _pageSize);
    final ticketsAsync = ref.watch(adminSupportTicketsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminSupportTicketsProvider(params)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: _statusOptions.map((s) => FilterChip(
                label: Text(s ?? 'All'),
                selected: _statusFilter == s,
                onSelected: (_) => setState(() { _statusFilter = s; _page = 1; }),
                selectedColor: AdminColors.accent.withValues(alpha: 0.15),
                checkmarkColor: AdminColors.accent,
              )).toList(),
            ),
          ),
          // Tickets list
          Expanded(
            child: ticketsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
              data: (result) {
                if (result.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.support_agent_rounded, size: 64, color: AdminColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('No Tickets Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: result.items.length,
                        itemBuilder: (context, index) => _TicketCard(
                          ticket: result.items[index],
                          onResolve: () => _resolveTicket(result.items[index].id),
                        ),
                      ),
                    ),
                    _PaginationBar(
                      page: result.page,
                      totalCount: result.totalCount,
                      pageSize: result.pageSize,
                      onPrev: () => setState(() => _page = (_page - 1).clamp(1, 999)),
                      onNext: () => setState(() => _page++),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _resolveTicket(String ticketId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Ticket'),
        content: const Text('Mark this support ticket as resolved?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminApiProvider).resolveSupportTicket(ticketId);
      ref.invalidate(adminSupportTicketsProvider(AdminTicketParams(status: _statusFilter, page: _page, pageSize: _pageSize)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket resolved'), backgroundColor: AdminColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AdminColors.danger));
      }
    }
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onResolve});
  final AdminSupportTicket ticket;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_sourceIcon(ticket.source), size: 24, color: AdminColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminColors.textPrimary)),
                      Text(ticket.userPhone, style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                    ],
                  ),
                ),
                _PriorityChip(priority: ticket.priority),
                const SizedBox(width: 8),
                _StatusChip(status: ticket.status),
              ],
            ),
            const Divider(height: 20),
            if (ticket.issueCategory != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.category_rounded, size: 16, color: AdminColors.textMuted),
                  const SizedBox(width: 8),
                  Text('Category: ', style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                  Text(ticket.issueCategory!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AdminColors.textPrimary)),
                ]),
              ),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 16, color: AdminColors.textMuted),
              const SizedBox(width: 8),
              Text('Created: ', style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
              Text(_timeAgo(ticket.createdAt), style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
            ]),
            if (ticket.resolvedAt != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AdminColors.success),
                const SizedBox(width: 8),
                Text('Resolved: ', style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                Text(_timeAgo(ticket.resolvedAt!), style: const TextStyle(fontSize: 13, color: AdminColors.success)),
              ]),
            ],
            if (ticket.status != 'Resolved') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Resolve'),
                  style: FilledButton.styleFrom(backgroundColor: AdminColors.success),
                  onPressed: onResolve,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'open': return AdminColors.info;
      case 'inprogress': return AdminColors.warning;
      case 'escalated': return AdminColors.danger;
      case 'resolved': return AdminColors.success;
      default: return AdminColors.textMuted;
    }
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final String priority;
  @override
  Widget build(BuildContext context) {
    final color = priority.toLowerCase() == 'critical' ? AdminColors.danger : priority.toLowerCase() == 'high' ? AdminColors.warning : AdminColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
      child: Text(priority, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.page, required this.totalCount, required this.pageSize, required this.onPrev, required this.onNext});
  final int page;
  final int totalCount;
  final int pageSize;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AdminColors.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: page > 1 ? onPrev : null),
          Text('Page ${page.clamp(1, totalPages)} of $totalPages · $totalCount items',
              style: const TextStyle(color: AdminColors.textPrimary)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: page < totalPages ? onNext : null),
        ],
      ),
    );
  }
}

IconData _sourceIcon(String source) {
  switch (source.toLowerCase()) {
    case 'sos': return Icons.warning_rounded;
    case 'phone': return Icons.phone_rounded;
    default: return Icons.support_agent_rounded;
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

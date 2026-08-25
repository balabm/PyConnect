import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/admin_providers.dart';
import '../data/admin_api.dart';

class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  String? _actionTypeFilter;
  int _page = 1;
  static const _pageSize = 50;

  static const _actionTypes = [
    null, 'ChangeUserRole', 'ActivateUser', 'DeactivateUser',
    'RejectDriverKyc', 'ResolveSosAlert', 'ResolveSupportTicket',
  ];

  @override
  Widget build(BuildContext context) {
    final params = AdminLogParams(actionType: _actionTypeFilter, page: _page, pageSize: _pageSize);
    final logsAsync = ref.watch(adminActionLogsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminActionLogsProvider(params)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: _actionTypes.map((t) => FilterChip(
                label: Text(t ?? 'All Actions'),
                selected: _actionTypeFilter == t,
                onSelected: (_) => setState(() { _actionTypeFilter = t; _page = 1; }),
                selectedColor: AdminColors.accent.withValues(alpha: 0.15),
                checkmarkColor: AdminColors.accent,
              )).toList(),
            ),
          ),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.accent)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.danger))),
              data: (result) {
                if (result.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 64, color: AdminColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('No Audit Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AdminColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Admin actions will appear here', style: TextStyle(color: AdminColors.textMuted)),
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
                        itemBuilder: (context, index) => _LogCard(log: result.items[index]),
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
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final AdminActionLog log;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _actionColor(log.actionType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_actionIcon(log.actionType), color: _actionColor(log.actionType), size: 20),
        ),
        title: Text(log.actionType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AdminColors.textPrimary)),
        subtitle: Text(
          '${log.entityType ?? 'N/A'} · ${_timeAgo(log.createdAt)}',
          style: TextStyle(fontSize: 12, color: AdminColors.textMuted),
        ),
        trailing: log.ipAddress != null
            ? Text(log.ipAddress!, style: TextStyle(fontSize: 11, color: AdminColors.textMuted))
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Admin User ID', value: log.adminUserId.substring(0, 8)),
                if (log.entityId != null) _DetailRow(label: 'Entity ID', value: log.entityId!.substring(0, 8)),
                if (log.payload != null) ...[
                  const SizedBox(height: 8),
                  Text('Payload:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.textMuted)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      log.payload!,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AdminColors.textPrimary),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Timestamp: ${log.createdAt.toIso8601String()}', style: TextStyle(fontSize: 11, color: AdminColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.contains('Reject') || action.contains('Deactivate')) return AdminColors.danger;
    if (action.contains('Resolve')) return AdminColors.success;
    if (action.contains('Approve') || action.contains('Activate')) return AdminColors.accent;
    if (action.contains('Change')) return AdminColors.warning;
    return AdminColors.info;
  }

  IconData _actionIcon(String action) {
    if (action.contains('Reject') || action.contains('Deactivate')) return Icons.block_rounded;
    if (action.contains('Resolve')) return Icons.check_circle_rounded;
    if (action.contains('Approve') || action.contains('Activate')) return Icons.check_rounded;
    if (action.contains('Change')) return Icons.swap_horiz_rounded;
    return Icons.history_rounded;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: AdminColors.textMuted, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AdminColors.textPrimary)),
      ]),
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
          Text('Page ${page.clamp(1, totalPages)} of $totalPages · $totalCount entries',
              style: const TextStyle(color: AdminColors.textPrimary)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: page < totalPages ? onNext : null),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

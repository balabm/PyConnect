import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/support_api.dart';

/// Support chat screen — a conversational interface to the support ticket
/// system. Users can send a message (which creates/continues a ticket) and
/// view their ticket history with AI replies and agent messages.
class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key, this.ticketId});

  /// Optional existing ticket ID to open directly.
  final String? ticketId;

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  List<SupportTicketModel> _tickets = [];
  String? _activeTicketId;
  List<TicketMessageModel> _messages = [];
  bool _loadingTickets = true;
  bool _loadingMessages = false;
  bool _sending = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activeTicketId = widget.ticketId;
    _loadTickets();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_activeTicketId != null) _loadMessages(_activeTicketId!);
    });
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      final tickets = await ref.read(supportApiProvider).getTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _loadingTickets = false;
          // Auto-select the most recent ticket if none is active.
          if (_activeTicketId == null && tickets.isNotEmpty) {
            _activeTicketId = tickets.first.id;
            _loadMessages(_activeTicketId!);
          } else if (_activeTicketId != null) {
            _loadMessages(_activeTicketId!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingTickets = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMessages(String ticketId) async {
    if (mounted) setState(() => _loadingMessages = true);
    try {
      final messages = await ref.read(supportApiProvider).getTicketMessages(ticketId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMessages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    AppHaptics.light();
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ref.read(supportApiProvider).sendMessage(text);
      _messageCtrl.clear();
      // Reload tickets and messages to show the new conversation.
      await _loadTickets();
      if (mounted) {
        setState(() => _activeTicketId = response.ticketId);
        await _loadMessages(response.ticketId);
        // Show AI reply as a snackbar if critical.
        if (response.isCritical) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Critical issue detected. An agent will contact you shortly.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              _loadTickets();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Ticket selector dropdown
          if (_tickets.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: DropdownButton<String>(
                value: _activeTicketId,
                isExpanded: true,
                underline: const SizedBox(),
                items: _tickets.map((t) {
                  final label = '${t.issueCategory ?? 'General'} • ${t.status}';
                  return DropdownMenuItem(
                    value: t.id,
                    child: Row(
                      children: [
                        _statusIcon(t.status),
                        const SizedBox(width: 8),
                        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() => _activeTicketId = id);
                    _loadMessages(id);
                  }
                },
              ),
            ),
          // Messages list
          Expanded(
            child: _loadingTickets
                ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
                : _error != null && _tickets.isEmpty
                    ? _buildEmptyState()
                    : _messages.isEmpty && !_loadingMessages
                        ? _buildWelcomeState()
                        : _loadingMessages && _messages.isEmpty
                            ? const Center(child: CircularProgressIndicator(color: AppTheme.emerald))
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final msg = _messages[index];
                                  final isUser = msg.senderRole.toLowerCase() == 'user';
                                  return _MessageBubble(
                                    text: msg.messageText,
                                    isUser: isUser,
                                    time: msg.createdAt,
                                  );
                                },
                              ),
          ),
          // Input bar
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, size: 36, color: AppTheme.emerald),
            ),
            const SizedBox(height: 20),
            const Text(
              'How can we help?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message describing your issue. Our AI assistant will respond instantly and escalate to a human agent if needed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickPrompt(label: 'Ride issue', onTap: () => _messageCtrl.text = 'I had an issue with my ride: '),
                _QuickPrompt(label: 'Food order', onTap: () => _messageCtrl.text = 'My food order has a problem: '),
                _QuickPrompt(label: 'Payment issue', onTap: () => _messageCtrl.text = 'I have a payment issue: '),
                _QuickPrompt(label: 'Refund request', onTap: () => _messageCtrl.text = 'I would like to request a refund for: '),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: AppTheme.slate.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Could not load tickets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _loadTickets,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 20),
              style: IconButton.styleFrom(backgroundColor: AppTheme.emerald),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    final s = status.toLowerCase();
    final color = s == 'open' ? AppTheme.warning : s == 'resolved' || s == 'closed' ? AppTheme.emerald : AppTheme.info;
    return Icon(Icons.circle, size: 10, color: color);
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser, required this.time});
  final String text;
  final bool isUser;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.emerald : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPrompt extends StatelessWidget {
  const _QuickPrompt({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: TextStyle(color: AppTheme.emerald, fontSize: 12, fontWeight: FontWeight.w500),
      side: BorderSide(color: AppTheme.emerald.withValues(alpha: 0.3)),
    );
  }
}

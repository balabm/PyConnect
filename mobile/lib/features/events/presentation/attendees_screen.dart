import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/p2p_event_api.dart';

/// Attendees screen — shows the host a list of all ticket holders.
class AttendeesScreen extends ConsumerStatefulWidget {
  const AttendeesScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  List<AttendeeModel> _attendees = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attendees =
          await ref.read(p2pEventApiProvider).getAttendees(widget.eventId);
      if (mounted) {
        setState(() {
          _attendees = attendees;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendees'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendees,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAttendees,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _attendees.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Icon(Icons.people_outline, size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'No attendees yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _attendees.length,
                        itemBuilder: (ctx, i) {
                          final a = _attendees[i];
                          final checkedIn = a.status == 'CheckedIn';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: checkedIn
                                    ? AppTheme.emerald
                                    : AppTheme.info.withValues(alpha: 0.2),
                                child: Icon(
                                  checkedIn ? Icons.check : Icons.person,
                                  color: checkedIn ? Colors.white : AppTheme.info,
                                ),
                              ),
                              title: Text(
                                a.buyerName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${a.pricePaid == 0 ? 'Free' : '₹${a.pricePaid.toStringAsFixed(0)}'} · ${a.status}',
                              ),
                              trailing: checkedIn
                                  ? Text(
                                      a.checkedInAt != null
                                          ? 'Checked in'
                                          : '',
                                      style: TextStyle(
                                        color: AppTheme.emerald,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

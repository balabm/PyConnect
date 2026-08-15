import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';

/// Table & Crowd Manager for Pub/Restobar/Club vendors.
/// Shows live crowd slider, table management, cover charge bookings, and guestlist.
class TableCrowdManagerScreen extends ConsumerStatefulWidget {
  const TableCrowdManagerScreen({super.key});

  @override
  ConsumerState<TableCrowdManagerScreen> createState() =>
      _TableCrowdManagerScreenState();
}

class _TableCrowdManagerScreenState
    extends ConsumerState<TableCrowdManagerScreen> {
  double _crowdLevel = 40; // percentage
  final List<Map<String, String>> _guestlist = [];
  final List<_TableInfo> _tables = [
    _TableInfo(id: 'T1', label: 'Table 1', seats: 4, status: 'Available'),
    _TableInfo(id: 'T2', label: 'Table 2', seats: 2, status: 'Occupied'),
    _TableInfo(id: 'T3', label: 'Table 3', seats: 6, status: 'Reserved'),
    _TableInfo(id: 'T4', label: 'VIP Booth', seats: 8, status: 'Available'),
    _TableInfo(id: 'T5', label: 'Table 5', seats: 4, status: 'Occupied'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table & Crowd Manager'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Crowd Slider
          _buildCrowdSection(),
          const SizedBox(height: 16),
          // Cover Charges
          _buildCoverChargeSection(),
          const SizedBox(height: 16),
          // Table Management
          _buildTableSection(),
          const SizedBox(height: 16),
          // Guestlist
          _buildGuestlistSection(),
        ],
      ),
    );
  }

  Widget _buildCrowdSection() {
    final crowdLabel = _crowdLevel < 33
        ? 'Chill'
        : _crowdLevel < 66
            ? 'Lively'
            : 'Packed';
    final crowdColor = _crowdLevel < 33
        ? AppTheme.emerald
        : _crowdLevel < 66
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups, color: AppTheme.emerald, size: 20),
              SizedBox(width: 8),
              Text('Live Crowd Meter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(crowdLabel,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: crowdColor)),
              Text('${_crowdLevel.round()}%',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: crowdColor)),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _crowdLevel,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: crowdColor,
            onChanged: (value) {
              AppHaptics.light();
              setState(() => _crowdLevel = value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Drag to update real-time occupancy. This is visible to consumers on the venue card.',
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverChargeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number, color: AppTheme.emerald, size: 20),
              SizedBox(width: 8),
              Text('Cover Charges',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _coverRow('Couples Entry', '\u20B91,000', '9 PM - 11 PM'),
          _coverRow('Stag Entry', '\u20B91,500', '9 PM - 11 PM'),
          _coverRow('VIP Table', '\u20B95,000', 'Includes 4 drinks'),
          _coverRow('Ladies Free', 'Free', 'Before 10 PM'),
        ],
      ),
    );
  }

  Widget _coverRow(String label, String price, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: AppTheme.emerald, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTableSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.table_restaurant, color: AppTheme.emerald, size: 20),
              SizedBox(width: 8),
              Text('Table Management',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ..._tables.map((t) => _buildTableTile(t)),
        ],
      ),
    );
  }

  Widget _buildTableTile(_TableInfo table) {
    final statusColor = table.status == 'Available'
        ? AppTheme.emerald
        : table.status == 'Occupied'
            ? AppTheme.danger
            : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.table_restaurant, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(table.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text('${table.seats} seats', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(table.status, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestlistSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 8),
              const Text('Guestlist',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_add, size: 20),
                onPressed: _addGuest,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_guestlist.isEmpty)
            Text('No guests on the list yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          else
            ..._guestlist.map((g) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 16, color: AppTheme.emerald),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g['name']!)),
                      Text(g['count']!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  void _addGuest() {
    final nameController = TextEditingController();
    final countController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add to Guestlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Guest Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countController,
              decoration: const InputDecoration(labelText: 'Party Size'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _guestlist.add({
                    'name': nameController.text,
                    'count': '${countController.text} pax',
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _TableInfo {
  _TableInfo({
    required this.id,
    required this.label,
    required this.seats,
    required this.status,
  });

  final String id;
  final String label;
  final int seats;
  String status;
}

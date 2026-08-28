import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/theme/app_theme.dart';
import '../application/vendor_providers.dart';
import '../data/vendor_dashboard_api.dart';
import 'manual_door_log_sheet.dart';

/// Drinks menu management for Pub/Club vendors.
/// Reuses the existing menu API but displays with beverage-themed UI.
/// Also hosts the Live Crowd slider and Guestlist management for nightlife.
class DrinksMenuScreen extends ConsumerStatefulWidget {
  const DrinksMenuScreen({super.key});

  @override
  ConsumerState<DrinksMenuScreen> createState() => _DrinksMenuScreenState();
}

class _DrinksMenuScreenState extends ConsumerState<DrinksMenuScreen> {
  int _crowdPercent = 25;
  final List<GuestlistEntryModel> _guestlist = [];
  bool _guestlistLoading = false;
  String? _venueId;

  @override
  void initState() {
    super.initState();
    _loadGuestlist();
    _loadVenueId();
  }

  Future<void> _loadVenueId() async {
    try {
      final venues = await ref.read(vendorDashboardApiProvider).getVenues();
      if (mounted && venues.isNotEmpty) {
        final venue = venues.first;
        setState(() {
          _venueId = venue.venueId;
          // Load current occupancy from venue data if available
          if (venue.maxCapacity > 0) {
            _crowdPercent = ((venue.currentCapacity / venue.maxCapacity) * 100)
                .round()
                .clamp(0, 100);
          }
        });
      }
    } catch (_) {
      // Venue will be loaded on next attempt.
    }
  }

  Future<void> _loadGuestlist() async {
    setState(() => _guestlistLoading = true);
    try {
      final entries = await ref.read(vendorDashboardApiProvider).getGuestlist();
      if (mounted) {
        setState(() {
          _guestlist.clear();
          _guestlist.addAll(entries);
          _guestlistLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guestlistLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load guestlist: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  String _vibeLabel(int pct) {
    if (pct <= 30) return 'Chill';
    if (pct <= 70) return 'Lively';
    return 'Packed';
  }

  Color _vibeColor(int pct) {
    if (pct <= 30) return AppTheme.emerald;
    if (pct <= 70) return AppTheme.warning;
    return AppTheme.danger;
  }

  /// Updates the venue's live occupancy percentage via the real backend
  /// endpoint POST /api/vendor/occupancy.
  Future<void> _updateOccupancy(int pct) async {
    try {
      final api = ref.read(vendorDashboardApiProvider);
      final venues = await api.getVenues();
      if (venues.isNotEmpty) {
        await api.updateOccupancy(venues.first.venueId, pct);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update occupancy: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _confirmDeleteDrink(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Drink?'),
        content: Text('Delete "$name" from your menu? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(vendorMenuProvider.notifier).deleteItem(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(vendorMenuProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Text('Drinks Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              AppHaptics.light();
              ref.read(vendorMenuProvider.notifier).load();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AppHaptics.light();
          _showAddDrinkSheet(context, ref);
        },
        child: Icon(Icons.add),
      ),
      body: menuAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCrowdSection(),
            const SizedBox(height: 16),
            _buildGuestlistSection(),
            const SizedBox(height: 32),
            const Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
          ],
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCrowdSection(),
            const SizedBox(height: 16),
            _buildGuestlistSection(),
            const SizedBox(height: 32),
            _buildError(context, ref, e.toString()),
          ],
        ),
        data: (items) {
          // Split items into VIP and regular
          final vipItems = items.where((i) => i.category == 'VIP').toList();
          final regularItems = items.where((i) => i.category != 'VIP').toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _buildCrowdSection(),
              const SizedBox(height: 16),
              _buildGuestlistSection(),
              const SizedBox(height: 16),
              _buildCoverChargeSection(),
              const SizedBox(height: 24),
              // VIP Menu Section
              if (vipItems.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 8),
                    Text('VIP Menu',
                        style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${vipItems.length} items',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFFFD700), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...vipItems.map((item) => _DrinkCard(
                      name: item.name,
                      category: item.category,
                      price: item.price,
                      isAvailable: item.isAvailable,
                      description: item.description,
                      isVip: true,
                      onToggle: () {
                        AppHaptics.light();
                        ref.read(vendorMenuProvider.notifier).toggleItem(item.id);
                      },
                      onDelete: () => _confirmDeleteDrink(item.id, item.name),
                    )),
                const SizedBox(height: 24),
              ],
              // Regular Drinks Menu
              Row(
                children: [
                  Icon(Icons.local_bar, color: AppTheme.emerald, size: 20),
                  SizedBox(width: 8),
                  Text('Drinks Menu',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (regularItems.isEmpty && vipItems.isEmpty)
                _buildEmpty()
              else
                ...regularItems.map((item) => _DrinkCard(
                      name: item.name,
                      category: item.category,
                      price: item.price,
                      isAvailable: item.isAvailable,
                      description: item.description,
                      onToggle: () {
                        AppHaptics.light();
                        ref.read(vendorMenuProvider.notifier).toggleItem(item.id);
                      },
                      onDelete: () => _confirmDeleteDrink(item.id, item.name),
                    )),
            ],
          );
        },
      ),
    );
  }

  // ── Live Crowd Section ──

  Widget _buildCrowdSection() {
    final vibe = _vibeLabel(_crowdPercent);
    final color = _vibeColor(_crowdPercent);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Text('Live Crowd',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vibe,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Prominent percentage indicator
          Center(
            child: Text(
              '$_crowdPercent%',
              style: TextStyle(
                color: color,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Visual occupancy bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _crowdPercent / 100,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _crowdPercent.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: AppTheme.emerald,
            inactiveColor: AppTheme.emerald.withValues(alpha: 0.15),
            label: '$_crowdPercent% - $vibe',
            onChanged: (v) {
              AppHaptics.selection();
              setState(() => _crowdPercent = v.round());
            },
            onChangeEnd: (v) {
              _updateOccupancy(v.round());
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Empty', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11)),
              Text('Full', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cover Charge Section ──

  Widget _buildCoverChargeSection() {
    // Cover charges are managed via live-tables check-in. No hardcoded
    // pricing — the actual cover charge is collected per booking.
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
              Icon(Icons.confirmation_number, color: AppTheme.emerald, size: 20),
              SizedBox(width: 8),
              Text('Cover Charges',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cover charges are collected per booking via the Live Tables screen. Use the Occupancy tile in Manage Hub to update live crowd percentage.',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  // ── Guestlist Section ──

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
              Icon(Icons.list_alt, color: AppTheme.emerald, size: 22),
              const SizedBox(width: 8),
              Text('Guestlist',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_guestlist.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_guestlist.where((g) => g.checkedIn).length}/${_guestlist.length}',
                    style: const TextStyle(
                        color: AppTheme.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_guestlist.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No guests on the list yet',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 13),
                ),
              ),
            )
          else
            ..._guestlist.asMap().entries.map((e) => _buildGuestlistTile(e.key, e.value)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emerald,
                side: const BorderSide(color: AppTheme.emerald, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                AppHaptics.light();
                _showAddGuestDialog(context);
              },
              icon: Icon(Icons.person_add, size: 18),
              label: Text('Add to Guestlist'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral.withValues(alpha: 0.1),
                foregroundColor: AppTheme.coral,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                AppHaptics.light();
                if (_venueId != null) {
                  showManualDoorLogSheet(context, ref, _venueId!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Venue not loaded yet. Try again.')),
                  );
                }
              },
              icon: Icon(Icons.door_front_door, size: 18),
              label: Text('Manual Door Entry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestlistTile(int index, GuestlistEntryModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.checkedIn
              ? AppTheme.emerald.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            entry.checkedIn ? Icons.check_circle : Icons.radio_button_unchecked,
            color: entry.checkedIn ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.guestName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: entry.checkedIn ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  'Party of ${entry.partySize}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            entry.checkedIn ? 'Checked In' : 'Pending',
            style: TextStyle(
              color: entry.checkedIn ? AppTheme.emerald : AppTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: entry.checkedIn
                  ? AppTheme.danger.withValues(alpha: 0.15)
                  : AppTheme.emerald.withValues(alpha: 0.15),
              foregroundColor: entry.checkedIn ? AppTheme.danger : AppTheme.emerald,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
            ),
            onPressed: () async {
              AppHaptics.light();
              final entry = _guestlist[index];
              try {
                if (entry.checkedIn) {
                  await ref.read(vendorDashboardApiProvider).undoCheckInGuest(entry.id);
                } else {
                  await ref.read(vendorDashboardApiProvider).checkInGuest(entry.id);
                }
                setState(() => entry.checkedIn = !entry.checkedIn);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: Text(entry.checkedIn ? 'Undo' : 'Check In'),
          ),
        ],
      ),
    );
  }

  void _showAddGuestDialog(BuildContext context) {
    final nameController = TextEditingController();
    final sizeController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Add to Guestlist', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Guest name',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sizeController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Party size',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.groups, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(),
            onPressed: () async {
              final name = nameController.text.trim();
              final size = int.tryParse(sizeController.text.trim()) ?? 1;
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a guest name'), backgroundColor: AppTheme.warning),
                );
                return;
              }
              AppHaptics.light();
              Navigator.pop(dialogContext);
              try {
                final entry = await ref.read(vendorDashboardApiProvider).addGuestlistEntry(
                      guestName: name,
                      partySize: size < 1 ? 1 : size,
                    );
                if (mounted) {
                  setState(() => _guestlist.insert(0, entry));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Menu helpers ──

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Could not load menu',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: () => ref.read(vendorMenuProvider.notifier).load(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.local_bar, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('No drinks on the menu yet',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 18)),
            const SizedBox(height: 8),
            Text('Tap + to add your first drink',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showAddDrinkSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const _AddDrinkSheet(),
    );
  }
}

class _DrinkCard extends StatelessWidget {
  const _DrinkCard({
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.description,
    required this.onToggle,
    this.onDelete,
    this.isVip = false,
  });

  final String name;
  final String category;
  final double price;
  final bool isAvailable;
  final String? description;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final bool isVip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isVip
            ? Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isVip
                  ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                  : AppTheme.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVip ? Icons.star : Icons.local_bar,
              color: isVip ? const Color(0xFFFFD700) : AppTheme.emerald,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '\u20B9${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppTheme.emerald,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                isAvailable ? 'In Stock' : 'Sold Out',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? AppTheme.emerald : AppTheme.danger,
                ),
              ),
              Switch(
                value: isAvailable,
                activeThumbColor: AppTheme.emerald,
                activeTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.emerald,
                inactiveTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
                onChanged: (_) => onToggle(),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppTheme.danger,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                  tooltip: 'Delete drink',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddDrinkSheet extends ConsumerStatefulWidget {
  const _AddDrinkSheet();

  @override
  ConsumerState<_AddDrinkSheet> createState() => _AddDrinkSheetState();
}

class _AddDrinkSheetState extends ConsumerState<_AddDrinkSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Cocktail');
  final _descriptionController = TextEditingController();
  bool _isVip = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;
    AppHaptics.light();
    setState(() => _submitting = true);
    try {
      await ref.read(vendorMenuProvider.notifier).createItem(
            CreateMenuItemPayload(
              name: _nameController.text,
              price: double.parse(_priceController.text),
              category: _isVip ? 'VIP' : _categoryController.text,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Drink',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildField(_nameController, 'Drink name', Icons.local_bar),
          const SizedBox(height: 12),
          _buildField(_priceController, 'Price (\u20B9)', Icons.payments, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildField(_categoryController, 'Category (Cocktail, Beer, Wine, Spirit)',
              Icons.category),
          const SizedBox(height: 12),
          _buildField(_descriptionController, 'Description (optional)', Icons.description, maxLines: 2),
          const SizedBox(height: 12),
          // VIP toggle
          SwitchListTile(
            title: Text('VIP Menu Item', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text(
              'Mark as premium/VIP exclusive',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12),
            ),
            value: _isVip,
            activeThumbColor: AppTheme.emerald,
            activeTrackColor: AppTheme.emerald.withValues(alpha: 0.3),
            onChanged: (v) {
              AppHaptics.light();
              setState(() => _isVip = v);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                  : Text('Add Drink'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.emerald),
        ),
      ),
    );
  }
}

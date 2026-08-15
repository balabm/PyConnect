import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/theme/app_theme.dart';
import '../application/stays_providers.dart';
import '../data/stays_api.dart';
import 'widgets/homestay_card.dart';

class StaysScreen extends ConsumerStatefulWidget {
  const StaysScreen({super.key});

  @override
  ConsumerState<StaysScreen> createState() => _StaysScreenState();
}

class _StaysScreenState extends ConsumerState<StaysScreen> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  bool _hasSearched = false;

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final guests = ref.watch(selectedGuestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boutique Stays'),
        actions: [
          IconButton(
            onPressed: () => context.go('/activity'),
            icon: const Icon(Icons.receipt_long),
            tooltip: 'My Bookings',
          ),
          IconButton(
            onPressed: () => ref.refresh(homestayListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          FadeSlideIn(
            child: _SearchBar(
              checkIn: _checkIn,
              checkOut: _checkOut,
              guests: guests,
              onCheckInSelected: (date) => setState(() {
                _checkIn = date;
                _hasSearched = false;
              }),
              onCheckOutSelected: (date) => setState(() {
                _checkOut = date;
                _hasSearched = false;
              }),
              onGuestsChanged: (value) {
                ref.read(selectedGuestsProvider.notifier).state = value;
              },
              onSearch: () => setState(() => _hasSearched = true),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(guests)),
        ],
      ),
    );
  }

  Widget _buildBody(int guests) {
    if (_hasSearched && _checkIn != null && _checkOut != null) {
      final params = HomestaySearchParams(
        checkIn: _formatDate(_checkIn!),
        checkOut: _formatDate(_checkOut!),
        guests: guests,
      );
      final searchAsync = ref.watch(homestaySearchProvider(params));
      return searchAsync.when(
        loading: () => const ShimmerList(count: 4, withImage: true),
        error: (e, _) => ErrorState(
          message: 'Search failed: $e',
          onRetry: () => ref.invalidate(homestaySearchProvider(params)),
        ),
        data: (results) {
          if (results.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'No stays available for these dates',
              subtitle: 'Try different dates or guest count.',
            );
          }
          return _HomestayListView(homestays: results);
        },
      );
    }

    final listAsync = ref.watch(homestayListProvider);
    return listAsync.when(
      loading: () => const ShimmerList(count: 4, withImage: true),
      error: (e, _) => ErrorState(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(homestayListProvider),
      ),
      data: (homestays) {
        if (homestays.isEmpty) {
          return const EmptyState(
            icon: Icons.home_outlined,
            title: 'No stays available yet',
            subtitle: 'Check back soon for boutique homestays.',
          );
        }
        return _HomestayListView(homestays: homestays);
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.onCheckInSelected,
    required this.onCheckOutSelected,
    required this.onGuestsChanged,
    required this.onSearch,
  });

  final DateTime? checkIn;
  final DateTime? checkOut;
  final int guests;
  final ValueChanged<DateTime> onCheckInSelected;
  final ValueChanged<DateTime> onCheckOutSelected;
  final ValueChanged<int> onGuestsChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [BoxShadow(color: AppTheme.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Check In',
                      date: checkIn,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) onCheckInSelected(date);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Check Out',
                      date: checkOut,
                      onTap: () async {
                        final first = checkIn ?? DateTime.now().add(const Duration(days: 1));
                        final date = await showDatePicker(
                          context: context,
                          initialDate: first.add(const Duration(days: 1)),
                          firstDate: first.add(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) onCheckOutSelected(date);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.group, size: 20, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  const Text('Guests'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: guests,
                    items: List.generate(10, (i) => i + 1)
                        .map((g) => DropdownMenuItem(
                              value: g,
                              child: Text('$g'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onGuestsChanged(value);
                    },
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                    onPressed: (checkIn != null && checkOut != null)
                        ? onSearch
                        : null,
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Location filter
              Row(
                children: [
                  Icon(Icons.place, size: 20, color: AppTheme.emerald),
                  const SizedBox(width: 8),
                  const Text('Location'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('All areas'),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All areas')),
                        DropdownMenuItem(value: 'White Town', child: Text('White Town')),
                        DropdownMenuItem(value: 'Heritage French Quarter', child: Text('Heritage French Quarter')),
                        DropdownMenuItem(value: 'Auroville Road', child: Text('Auroville Road')),
                        DropdownMenuItem(value: 'Beach Road', child: Text('Beach Road')),
                      ],
                      onChanged: (value) {
                        // Location filter is handled client-side via the list filter
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () { AppHaptics.light(); onTap(); },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                color: date != null ? AppTheme.emerald : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomestayListView extends StatelessWidget {
  const _HomestayListView({required this.homestays});

  final List<Homestay> homestays;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: homestays.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final homestay = homestays[index];
        return FadeSlideIn(
          delay: Duration(milliseconds: index * 80),
          child: HomestayCard(
            homestay: homestay,
            onTap: () { AppHaptics.light(); context.go('/stays/${homestay.id}'); },
          ),
        );
      },
    );
  }
}

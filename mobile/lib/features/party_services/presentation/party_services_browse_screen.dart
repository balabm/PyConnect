import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/party_services_api.dart';

/// Consumer screen for browsing party services (DJ, bartender, catering, etc.)
class PartyServicesBrowseScreen extends ConsumerStatefulWidget {
  const PartyServicesBrowseScreen({super.key});

  @override
  ConsumerState<PartyServicesBrowseScreen> createState() =>
      _PartyServicesBrowseScreenState();
}

class _PartyServicesBrowseScreenState
    extends ConsumerState<PartyServicesBrowseScreen> {
  String? _selectedCategory;

  static const _categories = [
    {'key': null, 'label': 'All', 'icon': Icons.celebration},
    {'key': 'DJ', 'label': 'DJ', 'icon': Icons.music_note},
    {'key': 'Bartender', 'label': 'Bartender', 'icon': Icons.local_bar},
    {'key': 'Catering', 'label': 'Catering', 'icon': Icons.restaurant},
    {'key': 'SoundSystem', 'label': 'Sound', 'icon': Icons.speaker},
    {'key': 'Lighting', 'label': 'Lighting', 'icon': Icons.lightbulb},
    {'key': 'Photography', 'label': 'Photo', 'icon': Icons.camera_alt},
    {'key': 'Decoration', 'label': 'Decor', 'icon': Icons.deck},
    {'key': 'Host', 'label': 'Host/MC', 'icon': Icons.mic},
    {'key': 'Security', 'label': 'Security', 'icon': Icons.security},
  ];

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(_partyServicesBrowseProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(title: const Text('Party Services')),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat['label'] as String),
                    avatar: Icon(cat['icon'] as IconData, size: 18),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = cat['key'] as String?;
                      });
                    },
                    selectedColor: AppTheme.emerald.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.emerald,
                  ),
                );
              }).toList(),
            ),
          ),
          // Services list
          Expanded(
            child: servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
                    const SizedBox(height: 12),
                    Text('Could not load services'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(_partyServicesBrowseProvider(_selectedCategory)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (services) {
                if (services.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppTheme.slate.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('No services found', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Try a different category', style: TextStyle(color: AppTheme.slate.withValues(alpha: 0.6))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: services.length,
                  itemBuilder: (context, index) => _ServiceCard(service: services[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final _partyServicesBrowseProvider = FutureProvider.family<List<PartyServiceModel>, String?>((ref, category) async {
  final api = ref.watch(partyServicesApiProvider);
  return await api.browse(category: category);
});

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final PartyServiceModel service;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/party-services/${service.id}', extra: service),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or placeholder
            if (service.imageUrl != null && service.imageUrl!.isNotEmpty)
              Image.network(
                service.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ImagePlaceholder(category: service.category),
              )
            else
              _ImagePlaceholder(category: service.category),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          service.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          service.category,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.vendorName,
                    style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.7)),
                  ),
                  if (service.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      service.description!,
                      style: TextStyle(fontSize: 13, color: AppTheme.slate.withValues(alpha: 0.6)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\u20B9${service.basePrice.toStringAsFixed(0)} ${service.pricingUnit}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.emerald),
                      ),
                      if (service.serviceArea != null)
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: AppTheme.slate.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              service.serviceArea!,
                              style: TextStyle(fontSize: 12, color: AppTheme.slate.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.category});
  final String category;

  IconData get _icon {
    switch (category) {
      case 'DJ': return Icons.music_note;
      case 'Bartender': return Icons.local_bar;
      case 'Catering': return Icons.restaurant;
      case 'SoundSystem': return Icons.speaker;
      case 'Lighting': return Icons.lightbulb;
      case 'Photography': return Icons.camera_alt;
      case 'Decoration': return Icons.deck;
      case 'Host': return Icons.mic;
      case 'Security': return Icons.security;
      default: return Icons.celebration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      color: AppTheme.emerald.withValues(alpha: 0.08),
      child: Icon(_icon, size: 48, color: AppTheme.emerald.withValues(alpha: 0.4)),
    );
  }
}

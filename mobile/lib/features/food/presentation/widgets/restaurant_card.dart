import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// Card displaying a restaurant/vendor with rating, prep time, delivery fee, and item count.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.vendor});

  final Map<String, dynamic> vendor;

  @override
  Widget build(BuildContext context) {
    final id = vendor['id'] as String;
    final name = vendor['name'] as String? ?? '';
    final cuisine = vendor['cuisineType'] as String?;
    final rating = vendor['rating'] as num?;
    final description = vendor['description'] as String?;
    final deliveryFee = vendor['deliveryFee'] as num?;
    final prepTime = vendor['prepTimeMinutes'] as num?;
    final itemCount = vendor['menuItemCount'] as int? ?? 0;
    final imageUrl = vendor['imageUrl'] as String? ?? vendor['image'] as String?;

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/food/vendor/$id?name=${Uri.encodeComponent(name)}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      borderRadius: 14,
                      fallbackIcon: Icons.restaurant,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.restaurant, size: 32, color: Color(0xFF6B7280)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (cuisine != null) ...[
                  const SizedBox(height: 2),
                  Text(cuisine, style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                ],
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    if (rating != null)
                      RatingStars(rating: rating.toDouble(), size: 14),
                    if (prepTime != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('${prepTime.toInt()} min', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.two_wheeler, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(
                          deliveryFee != null ? '\u20B9${deliveryFee.toInt()}' : 'Free',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (itemCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text('$itemCount items', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/design.dart';
import '../../../../core/theme/app_theme.dart';

/// Card displaying a restaurant/vendor with rating, prep time, delivery fee, and item count.
/// When [isAcceptingOrders] is false, the card is greyed out and shows a
/// "Currently Unavailable" banner — the vendor has paused orders via the
/// master toggle, broadcast in real-time via SignalR.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.vendor, this.isAcceptingOrders = true});

  final Map<String, dynamic> vendor;
  final bool isAcceptingOrders;

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
    final isVegOnly = vendor['isVegOnly'] as bool? ?? false;
    final priceTier = vendor['priceTier'] as int? ?? 1;
    final discountTag = vendor['discountTag'] as String?;

    // Pricing tier: 1=₹, 2=₹₹, 3=₹₹₹
    final priceTierStr = List.generate(priceTier, (_) => '\u20B9').join();

    final deliveryFeeValue = (deliveryFee ?? 0).toDouble();

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: isAcceptingOrders
          ? () => context.push(
              '/food/vendor/$id?name=${Uri.encodeComponent(name)}&deliveryFee=$deliveryFeeValue')
          : null,
      child: Opacity(
        opacity: isAcceptingOrders ? 1.0 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 cover photo
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.restaurant,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.emerald.withValues(alpha: 0.08),
                                  AppTheme.emerald.withValues(alpha: 0.03),
                                ],
                              ),
                            ),
                            child: Icon(Icons.restaurant, size: 40, color: AppTheme.emerald.withValues(alpha: 0.4)),
                          ),
                  ),
                ),
                if (!isAcceptingOrders)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: const Text(
                          'Currently Unavailable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Info row
            Row(
              children: [
                // Veg/non-veg badge
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isVegOnly ? AppTheme.emerald : AppTheme.danger,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Icon(
                    isVegOnly ? Icons.circle : Icons.change_circle,
                    size: 8,
                    color: isVegOnly ? AppTheme.emerald : AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                // Pricing tier
                Text(
                  priceTierStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (cuisine != null) ...[
                  const SizedBox(width: 6),
                  Text('· $cuisine', style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            if (discountTag != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  discountTag,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                ),
              ),
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
    );
  }
}

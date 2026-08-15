import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/providers.dart';

final lateNightProductsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(essentialsApiProvider);
  return await api.listProducts(lateNight: true);
});

final allEssentialsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(essentialsApiProvider);
  return await api.listProducts();
});

final storeBundleSuggestionsProvider =
    FutureProvider.family<List<dynamic>, List<String>>((ref, productIds) async {
  if (productIds.isEmpty) return [];
  final api = ref.watch(essentialsApiProvider);
  return await api.getSuggestions(productIds);
});

class EssentialsStoreView extends ConsumerStatefulWidget {
  const EssentialsStoreView({super.key});

  @override
  ConsumerState<EssentialsStoreView> createState() =>
      _EssentialsStoreViewState();
}

class _EssentialsStoreViewState extends ConsumerState<EssentialsStoreView> {
  final _cart = <String, int>{};
  final _productCache = <String, Map<String, dynamic>>{};
  bool _loading = false;

  List<String> get _cartProductIds => _cart.keys.toList();

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  void _addToCart(String id) {
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
  }

  void _removeFromCart(String id) {
    setState(() {
      final count = _cart[id] ?? 0;
      if (count <= 1) {
        _cart.remove(id);
      } else {
        _cart[id] = count - 1;
      }
    });
  }

  Future<void> _quickCheckout() async {
    setState(() => _loading = true);
    final items = _cart.entries
        .map((e) => {'productId': e.key, 'quantity': e.value})
        .toList();

    try {
      final api = ref.read(essentialsApiProvider);
      final result = await api.createOrder({
        'deliveryAddress': '12 Rue Romain Rolland, White Town',
        'deliveryLatitude': 11.9362,
        'deliveryLongitude': 79.8346,
        'items': items,
      });
      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (_) => _CheckoutResultSheet(result: result),
        );
        setState(() => _cart.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lateNightAsync = ref.watch(lateNightProductsProvider);
    final allProductsAsync = ref.watch(allEssentialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party & Beach Essentials'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Order History',
            onPressed: () => context.push('/essentials/orders'),
          ),
        ],
      ),
      body: allProductsAsync.when(
        loading: () => const ShimmerList(withImage: true, count: 6),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(lateNightProductsProvider);
            ref.invalidate(allEssentialsProvider);
          },
        ),
        data: (allProducts) {
          for (final p in allProducts) {
            _productCache[p['id'] as String] = p as Map<String, dynamic>;
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(lateNightProductsProvider);
                  ref.invalidate(allEssentialsProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    // Late Night Needs Carousel
                    SliverToBoxAdapter(
                      child: lateNightAsync.when(
                        loading: () => const SizedBox(
                          height: 180,
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (lateNightProducts) {
                          if (lateNightProducts.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _LateNightCarousel(
                            products: lateNightProducts,
                            cart: _cart,
                            onAdd: _addToCart,
                            onRemove: _removeFromCart,
                          );
                        },
                      ),
                    ),

                    // Section header for all products
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'All Products',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),

                    // Quick-add grid
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: _cartCount > 0 ? 160 : 16,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product =
                                allProducts[index] as Map<String, dynamic>;
                            return _QuickAddCard(
                              product: product,
                              inCart: _cart[product['id']] ?? 0,
                              onAdd: () =>
                                  _addToCart(product['id'] as String),
                              onRemove: () =>
                                  _removeFromCart(product['id'] as String),
                            );
                          },
                          childCount: allProducts.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bundle suggestions + cart bar
              if (_cartCount > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(
                    cartProductIds: _cartProductIds,
                    cartCount: _cartCount,
                    loading: _loading,
                    onCheckout: _quickCheckout,
                    onClear: () => setState(() => _cart.clear()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LateNightCarousel extends StatelessWidget {
  const _LateNightCarousel({
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  final List<dynamic> products;
  final Map<String, int> cart;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.nightlight_round,
                    color: Colors.amber.shade300, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Late Night Needs',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Fast delivery',
                  style: TextStyle(
                    color: Colors.indigo.shade200,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index] as Map<String, dynamic>;
                final id = product['id'] as String;
                final inCart = cart[id] ?? 0;
                return Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade800.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.indigo.shade400.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _categoryIcon(product['category'] as String? ?? ''),
                          color: Colors.indigo.shade200,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product['name'] as String? ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\u20B9${product['price']}',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (inCart == 0)
                              GestureDetector(
                                onTap: () => onAdd(id),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade300,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.add,
                                      size: 16, color: Colors.indigo.shade900),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => onRemove(id),
                                    child: Icon(Icons.remove_circle_outline,
                                        size: 20, color: Colors.indigo.shade200),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text(
                                      '$inCart',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => onAdd(id),
                                    child: Icon(Icons.add_circle,
                                        size: 20, color: Colors.amber.shade300),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({
    required this.product,
    required this.inCart,
    required this.onAdd,
    required this.onRemove,
  });

  final Map<String, dynamic> product;
  final int inCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isLateNight = product['isLateNightEssential'] as bool? ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).dividerColor,
                child: Center(
                  child: Icon(
                    _categoryIcon(product['category'] as String? ?? ''),
                    size: 36,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLateNight)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('Late Night',
                          style: TextStyle(
                              fontSize: 9, color: Colors.indigo.shade700)),
                    ),
                  if (isLateNight) const SizedBox(height: 4),
                  Text(
                    product['name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '\u20B9${product['price']}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  if (inCart == 0)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                          onPressed: onAdd, child: const Text('Add')),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: onRemove,
                            visualDensity: VisualDensity.compact),
                        Text('$inCart',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: onAdd,
                            visualDensity: VisualDensity.compact),
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

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.cartProductIds,
    required this.cartCount,
    required this.loading,
    required this.onCheckout,
    required this.onClear,
  });

  final List<String> cartProductIds;
  final int cartCount;
  final bool loading;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync =
        ref.watch(storeBundleSuggestionsProvider(cartProductIds));

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bundle suggestions strip
          suggestionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (suggestions) {
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 70,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        'You might also need',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final sug =
                              suggestions[index] as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(
                                '${sug['name']} \u20B9${sug['price']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () {
                                // Navigate to full essentials to add
                                context.push('/essentials');
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Cart bar
          Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$cartCount items',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: onClear,
                          tooltip: 'Clear cart'),
                      FilledButton.icon(
                        onPressed: loading ? null : onCheckout,
                        icon: loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.bolt),
                        label: const Text('Quick Checkout'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutResultSheet extends StatelessWidget {
  const _CheckoutResultSheet({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Placed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FareRow(label: 'Subtotal', value: '\u20B9${result['subTotal']}'),
          FareRow(label: 'Delivery Fee', value: '\u20B9${result['deliveryFee']}'),
          if (result['platformFee'] != null)
            FareRow(label: 'Platform Fee', value: '\u20B9${result['platformFee']}'),
          const Divider(),
          FareRow(label: 'Total', value: '\u20B9${result['totalAmount']}', bold: true),
          const SizedBox(height: 8),
          Text('Status: ${result['status']}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'HydrationRecovery':
      return Icons.water_drop;
    case 'SmokingAccessories':
      return Icons.smoking_rooms;
    case 'BeachEssentials':
      return Icons.beach_access;
    case 'Snacks':
      return Icons.fastfood;
    default:
      return Icons.category;
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

final essentialsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(essentialsApiProvider);
  return await api.listProducts();
});

final flashPromosProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.watch(publicApiProvider);
  return await api.listFlashPromos();
});

final bundleSuggestionsProvider = FutureProvider.family<List<dynamic>, List<String>>((ref, productIds) async {
  if (productIds.isEmpty) return [];
  final api = ref.watch(essentialsApiProvider);
  return await api.getSuggestions(productIds);
});

class EssentialsScreen extends ConsumerStatefulWidget {
  const EssentialsScreen({super.key});

  @override
  ConsumerState<EssentialsScreen> createState() => _EssentialsScreenState();
}

class _EssentialsScreenState extends ConsumerState<EssentialsScreen> {
  final _cart = <String, int>{};
  final _productCache = <String, Map<String, dynamic>>{};
  String _searchQuery = '';
  String? _categoryFilter;
  bool _lateNightOnly = false;
  bool _loading = false;

  static const _categories = ['All', 'HydrationRecovery', 'SmokingAccessories', 'BeachEssentials', 'Snacks'];

  List<dynamic> _filterProducts(List<dynamic> products) {
    return products.where((p) {
      final map = p as Map<String, dynamic>;
      final name = (map['name'] as String? ?? '').toLowerCase();
      final category = map['category'] as String? ?? '';
      final isLateNight = map['isLateNightEssential'] as bool? ?? false;
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCategory = _categoryFilter == null || _categoryFilter == 'All' || category == _categoryFilter;
      final matchesLateNight = !_lateNightOnly || isLateNight;
      return matchesSearch && matchesCategory && matchesLateNight;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(essentialsListProvider);
    final promosAsync = ref.watch(flashPromosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Essentials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront),
            tooltip: 'Quick Store',
            onPressed: () => context.push('/essentials/store'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Order History',
            onPressed: () => context.push('/essentials/orders'),
          ),
        ],
      ),
      body: Column(
        children: [
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    borderSide: const BorderSide(color: AppTheme.emerald, width: 2),
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ..._categories.map((cat) => _buildPill(
                        _categoryLabel(cat),
                        _categoryFilter == cat,
                        () => setState(() => _categoryFilter = cat),
                      )),
                  _buildPill(
                    'Late Night',
                    _lateNightOnly,
                    () => setState(() => _lateNightOnly = !_lateNightOnly),
                    icon: Icons.nightlight_round,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: productsAsync.when(
              loading: () => const ShimmerList(count: 6, withImage: true),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(essentialsListProvider),
              ),
              data: (products) {
                for (final p in products) {
                  _productCache[p['id'] as String] = p as Map<String, dynamic>;
                }
                final filtered = _filterProducts(products);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'No products found',
                    subtitle: 'Try a different search or filter.',
                  );
                }
                final cartCount = _cart.values.fold(0, (a, b) => a + b);
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () => ref.refresh(essentialsListProvider.future),
                      child: CustomScrollView(
                        slivers: [
                          if (promosAsync.hasValue && promosAsync.value!.isNotEmpty)
                            SliverToBoxAdapter(child: _FlashPromoBanner(promos: promosAsync.value!)),
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 8,
                              bottom: cartCount > 0 ? 90 : 16,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => FadeSlideIn(
                                  delay: Duration(milliseconds: index * 50),
                                  child: _ProductCard(
                                    product: filtered[index] as Map<String, dynamic>,
                                    inCart: _cart[filtered[index]['id']] ?? 0,
                                    onAdd: () {
                                      AppHaptics.light();
                                      _addToCart(filtered[index]['id'] as String);
                                    },
                                    onRemove: () {
                                      AppHaptics.light();
                                      _removeFromCart(filtered[index]['id'] as String);
                                    },
                                    onTap: () {
                                      AppHaptics.light();
                                      _showProductDetail(filtered[index] as Map<String, dynamic>);
                                    },
                                  ),
                                ),
                                childCount: filtered.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: FadeSlideIn(
                          child: _CartBar(
                            itemCount: cartCount,
                            loading: _loading,
                            onCheckout: _checkout,
                            onClear: () => setState(() => _cart.clear()),
                          ),
                        ),
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

  Widget _buildPill(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.emerald : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? AppTheme.emerald : Theme.of(context).dividerColor),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'HydrationRecovery':
        return 'Hydration';
      case 'SmokingAccessories':
        return 'Smoking';
      case 'BeachEssentials':
        return 'Beach';
      case 'Snacks':
        return 'Snacks';
      default:
        return cat;
    }
  }

  void _showProductDetail(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductDetailSheet(
        product: product,
        inCart: _cart[product['id']] ?? 0,
        onAdd: () {
          setState(() => _addToCart(product['id'] as String));
          Navigator.pop(context);
        },
        onRemove: () {
          setState(() => _removeFromCart(product['id'] as String));
        },
      ),
    );
  }

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

  Future<void> _checkout() async {
    setState(() => _loading = true);
    final items = _cart.entries.map((e) => {
      'productId': e.key,
      'quantity': e.value,
    }).toList();

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
          builder: (_) => _OrderResultSheet(result: result),
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
}

class _FlashPromoBanner extends StatefulWidget {
  const _FlashPromoBanner({required this.promos});
  final List<dynamic> promos;

  @override
  State<_FlashPromoBanner> createState() => _FlashPromoBannerState();
}

class _FlashPromoBannerState extends State<_FlashPromoBanner> {
  Timer? _timer;
  final _countdowns = <int, Duration>{};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.promos.length; i++) {
      final promo = widget.promos[i] as Map<String, dynamic>;
      final expiry = promo['expiryTime'] as String?;
      if (expiry != null) {
        final diff = DateTime.parse(expiry).difference(DateTime.now());
        if (diff.isNegative) continue;
        _countdowns[i] = diff;
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        for (final key in _countdowns.keys.toList()) {
          final d = _countdowns[key]! - const Duration(seconds: 1);
          if (d.isNegative) {
            _countdowns.remove(key);
          } else {
            _countdowns[key] = d;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.promos.length,
        itemBuilder: (context, index) {
          final promo = widget.promos[index] as Map<String, dynamic>;
          final countdown = _countdowns[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.warning, AppTheme.danger]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        '${promo['discountPercentage']}% OFF',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (countdown != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${countdown.inMinutes.remainder(60).toString().padLeft(2, '0')}:${countdown.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    promo['title'] as String? ?? 'Flash Sale',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.inCart,
    required this.onAdd,
    required this.onRemove,
    required this.onTap,
  });

  final Map<String, dynamic> product;
  final int inCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLateNight = product['isLateNightEssential'] as bool? ?? false;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.emerald.withValues(alpha: 0.1),
                        AppTheme.emerald.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _categoryIcon(product['category'] as String? ?? ''),
                      size: 40,
                      color: AppTheme.emerald.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLateNight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text('Late Night', style: TextStyle(fontSize: 9, color: Colors.indigo.shade700, fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      product['name'] as String? ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('\u20B9${product['price']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                    if (inCart == 0)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.emerald.withValues(alpha: 0.08),
                            foregroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: onAdd,
                          child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: onRemove, visualDensity: VisualDensity.compact, color: AppTheme.emerald),
                            Text('$inCart', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                            IconButton(icon: const Icon(Icons.add, size: 16), onPressed: onAdd, visualDensity: VisualDensity.compact, color: AppTheme.emerald),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _ProductDetailSheet extends ConsumerWidget {
  const _ProductDetailSheet({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final productId = product['id'] as String?;
    final suggestionsAsync = productId != null && inCart > 0
        ? ref.watch(bundleSuggestionsProvider([productId]))
        : const AsyncValue<List<dynamic>>.data([]);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              product['name'] as String? ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '\u20B9${product['price']}',
              style: const TextStyle(fontSize: 20, color: AppTheme.success, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (product['description'] != null)
              Text(product['description'] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),
            if (product['isLateNightEssential'] as bool? ?? false)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.indigo.shade100, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nightlight_round, size: 16, color: Colors.indigo.shade700),
                    const SizedBox(width: 4),
                    Text('Late Night Essential', style: TextStyle(color: Colors.indigo.shade700, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (inCart > 0) ...[
                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: onRemove),
                  Text('$inCart', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(inCart > 0 ? 'Add More' : 'Add to Cart'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            suggestionsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (_, _) => const SizedBox.shrink(),
              data: (suggestions) {
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bundle Suggestions', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final sug = suggestions[index] as Map<String, dynamic>;
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sug['name'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Text('\u20B9${sug['price']}', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.itemCount, required this.loading, required this.onCheckout, required this.onClear});
  final int itemCount;
  final bool loading;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.emeraldGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$itemCount items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.clear_all, color: Colors.white70), onPressed: onClear, tooltip: 'Clear cart'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.emerald,
                      ),
                      onPressed: loading ? null : onCheckout,
                      icon: loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.shopping_cart_checkout),
                      label: const Text('Checkout'),
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

class _OrderResultSheet extends StatelessWidget {
  const _OrderResultSheet({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScaleFadeIn(
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.emeraldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.check_circle, size: 36, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Center(
              child: Text('Order Placed!', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(delay: const Duration(milliseconds: 300), child: FareRow(label: 'Subtotal', value: '\u20B9${result['subTotal']}')),
          FadeSlideIn(delay: const Duration(milliseconds: 350), child: FareRow(label: 'Delivery Fee', value: '\u20B9${result['deliveryFee']}')),
          if (result['platformFee'] != null)
            FadeSlideIn(delay: const Duration(milliseconds: 400), child: FareRow(label: 'Platform Fee', value: '\u20B9${result['platformFee']}')),
          const Divider(),
          FadeSlideIn(delay: const Duration(milliseconds: 450), child: FareRow(label: 'Total', value: '\u20B9${result['totalAmount']}', bold: true)),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('Status: ${result['status']}', style: TextStyle(color: AppTheme.emerald, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

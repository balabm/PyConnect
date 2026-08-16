import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/design/design.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/quick_auth_sheet.dart';

final menuProvider = FutureProvider.family<List<dynamic>, String>((ref, vendorId) async {
  final api = ref.watch(foodApiProvider);
  return await api.getMenu(vendorId);
});

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({
    super.key,
    required this.vendorId,
    this.vendorName,
  });

  final String vendorId;
  final String? vendorName;

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  final _cart = <int, int>{}; // original index -> quantity
  bool _loading = false;
  String _searchQuery = '';
  String? _categoryFilter;

  /// Syncs the local cart count to the global provider so the home screen
  /// cart badge reflects the current number of items.
  void _syncCartCount() {
    final count = _cart.values.fold(0, (a, b) => a + b);
    ref.read(cartItemCountProvider.notifier).state = count;
  }

  @override
  void initState() {
    super.initState();
    // Initialize Razorpay SDK early so it's ready at checkout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(razorpayPaymentProvider).init();
    });
  }

  /// Extracts unique categories from the menu items dynamically.
  List<String> _extractCategories(List<dynamic> items) {
    final cats = <String>{};
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final cat = map['category'] as String?;
      if (cat != null && cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList()..sort();
  }

  List<dynamic> _filterItems(List<dynamic> items) {
    if (_searchQuery.isEmpty && _categoryFilter == null) return items;
    return items.where((item) {
      final map = item as Map<String, dynamic>;
      final name = (map['name'] as String? ?? '').toLowerCase();
      final category = map['category'] as String? ?? '';
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCategory = _categoryFilter == null || category == _categoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider(widget.vendorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vendorName ?? 'Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Order History',
            onPressed: () => context.push('/food/orders'),
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
                  hintText: 'Search menu...',
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
              child: menuAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) {
                  final categories = _extractCategories(items);
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildPill('All', _categoryFilter == null, () {
                        AppHaptics.selection();
                        setState(() => _categoryFilter = null);
                      }),
                      ...categories.map((cat) => _buildPill(cat, _categoryFilter == cat, () {
                            AppHaptics.selection();
                            setState(() => _categoryFilter = cat);
                          })),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: menuAsync.when(
              loading: () => const ShimmerList(withImage: false, count: 6),
              error: (e, _) => ErrorState(
                message: 'Could not load menu. Please try again.',
                onRetry: () => ref.invalidate(menuProvider(widget.vendorId)),
              ),
              data: (items) {
                final filtered = _filterItems(items);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No items found',
                    subtitle: 'Try a different search or category.',
                  );
                }
                final cartCount = _cart.values.fold(0, (a, b) => a + b);
                final subtotal = _cart.entries.fold(0.0, (sum, entry) {
                  final item = items[entry.key] as Map<String, dynamic>;
                  return sum + (item['price'] as num).toDouble() * entry.value;
                });

                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () => ref.refresh(menuProvider(widget.vendorId).future),
                      child: ListView.builder(
                        padding: EdgeInsets.only(bottom: cartCount > 0 ? 90 : 16, top: 4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index] as Map<String, dynamic>;
                          final originalIndex = items.indexOf(item);
                          final qty = _cart[originalIndex] ?? 0;
                          return FadeSlideIn(
                            delay: Duration(milliseconds: index * 50),
                            child: _MenuItemTile(
                              name: item['name'] as String? ?? '',
                              description: item['description'] as String?,
                              price: (item['price'] as num).toDouble(),
                              category: item['category'] as String?,
                              isLateNight: item['isLateNight'] as bool? ?? false,
                              isVeg: item['isVeg'] as bool? ?? false,
                              imageUrl: item['imageUrl'] as String?,
                              quantity: qty,
                              onAdd: () {
                                AppHaptics.light();
                                setState(() {
                                  _cart[originalIndex] = qty + 1;
                                  _syncCartCount();
                                });
                              },
                              onRemove: () {
                                AppHaptics.light();
                                setState(() {
                                  if (qty <= 1) {
                                    _cart.remove(originalIndex);
                                  } else {
                                    _cart[originalIndex] = qty - 1;
                                  }
                                  _syncCartCount();
                                });
                              },
                              onCardTap: () {
                                AppHaptics.light();
                                _showCustomizationSheet(item, originalIndex, qty);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (cartCount > 0)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: FadeSlideIn(
                          child: _CheckoutBar(
                            itemCount: cartCount,
                            subtotal: subtotal,
                            loading: _loading,
                            onCheckout: () {
                              AppHaptics.medium();
                              _showCartSummarySheet(items, subtotal);
                            },
                            onClear: () {
                              AppHaptics.light();
                              setState(() {
                                _cart.clear();
                                _syncCartCount();
                              });
                            },
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

  Future<void> _showCustomizationSheet(
      Map<String, dynamic> item, int originalIndex, int currentQty) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemCustomizationSheet(item: item, currentQty: currentQty),
    );
    if (result != null && mounted) {
      AppHaptics.light();
      final qty = result['quantity'] as int? ?? 1;
      setState(() {
        _cart[originalIndex] = (_cart[originalIndex] ?? 0) + qty;
        _syncCartCount();
      });
    }
  }

  Widget _buildPill(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.emerald : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppTheme.emerald : Theme.of(context).dividerColor,
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCartSummarySheet(List<dynamic> items, double subtotal) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSummarySheet(
        items: items,
        cart: Map.fromEntries(
          _cart.entries.map((e) => MapEntry(e.key, e.value)),
        ),
        subtotal: subtotal,
      ),
    );
    if (result != null && result['confirmed'] == true && mounted) {
      _checkout(
        items,
        subtotal,
        paymentMethod: result['paymentMethod'] as int? ?? 0,
        deliveryAddress: result['deliveryAddress'] as String?,
      );
    }
  }

  Future<void> _checkout(
    List<dynamic> items,
    double subtotal, {
    int paymentMethod = 0,
    String? deliveryAddress,
  }) async {
    // Check auth — if not signed in, show QuickAuthSheet before proceeding
    final isAuthed = ref.read(authTokenProvider)?.isNotEmpty ?? false;
    if (!isAuthed) {
      final authenticated = await QuickAuthSheet.show(
        context,
        ref,
        title: 'Sign in to order',
      );
      if (authenticated != true || !mounted) return;
    }

    setState(() => _loading = true);
    try {
      final cartItems = _cart.entries.map((e) {
        final item = items[e.key] as Map<String, dynamic>;
        return {
          'name': item['name'],
          'quantity': e.value,
          'unitPrice': item['price'],
        };
      }).toList();

      final api = ref.read(foodApiProvider);

      // Use the device's current location as the delivery address
      double deliveryLat = 11.9416; // Default: White Town, Pondicherry
      double deliveryLng = 79.8083;
      String address = deliveryAddress ?? 'Current Location, Pondicherry';

      try {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
          deliveryLat = position.latitude;
          deliveryLng = position.longitude;
        }
      } catch (_) {
        // Fall back to default Pondicherry coordinates
      }

      // paymentMethod: 0 = Razorpay (online, maps to 1), 1 = Cash on Delivery (maps to 2)
      final apiPaymentMethod = paymentMethod == 1 ? 2 : 1;

      final result = await api.checkout({
        'vendorId': widget.vendorId,
        'deliveryAddress': address,
        'deliveryLatitude': deliveryLat,
        'deliveryLongitude': deliveryLng,
        'paymentMethod': apiPaymentMethod,
        'items': cartItems,
      });

      final totalAmount = (result['totalAmount'] as num?)?.toDouble() ?? subtotal;
      final foodOrderId = result['orderId'] as String?;

      if (mounted) {
        setState(() {
          _cart.clear();
          _syncCartCount();
        });
        if (paymentMethod == 1) {
          // Cash on Delivery — skip Razorpay, show success directly
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              builder: (_) => _CheckoutResultSheet(result: result),
            );
          }
        } else {
          await _initiateRazorpayPayment(
            foodOrderId: foodOrderId,
            amount: totalAmount,
            orderResult: result,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initiateRazorpayPayment({
    required String? foodOrderId,
    required double amount,
    required Map<String, dynamic> orderResult,
  }) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    try {
      final order = await paymentService.createOrder(
        amount: amount,
        foodOrderId: foodOrderId,
      );

      if (!mounted) return;

      // Show processing overlay while Razorpay checkout opens
      _showProcessingOverlay();

      final paymentResult = await paymentService.startPayment(
        orderId: order.providerOrderId,
        amount: (amount * 100).round(), // paise
        phone: authSession?.phone ?? '',
        userName: authSession?.name,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss overlay

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          // Verify payment signature on backend before confirming.
          await paymentService.verifyPayment(
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
          );
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              builder: (_) => _CheckoutResultSheet(result: orderResult),
            );
          }
        case PaymentError(:final code, :final message):
          if (mounted) {
            _showPaymentErrorSnackBar(code, message, () {
              _initiateRazorpayPayment(
                foodOrderId: foodOrderId,
                amount: amount,
                orderResult: orderResult,
              );
            });
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('External wallet selected. Please complete payment.')),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initiation failed: $e')),
        );
      }
    }
  }

  void _showProcessingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Processing payment...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please wait for confirmation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPaymentErrorSnackBar(int code, String message, VoidCallback onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $message (code $code)'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry Payment',
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isLateNight,
    required this.isVeg,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    required this.onCardTap,
    this.imageUrl,
  });

  final String name;
  final String? description;
  final double price;
  final String? category;
  final bool isLateNight;
  final bool isVeg;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onCardTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardShadow
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Veg/non-veg indicator
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVeg ? AppTheme.emerald : AppTheme.danger,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Icon(
                        isVeg ? Icons.circle : Icons.change_circle,
                        size: 8,
                        color: isVeg ? AppTheme.emerald : AppTheme.danger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isLateNight) ...[
                      Icon(Icons.nightlight_round, size: 14, color: AppTheme.info.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                    ],
                    Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('\u20B9${price.toStringAsFixed(0)}', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w700, fontSize: 15)),
                    if (category != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.emerald.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(category!, style: TextStyle(fontSize: 10, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Item thumbnail (64x64, 1:1 aspect ratio)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      fallbackIcon: Icons.restaurant_outlined,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.restaurant_outlined,
                        size: 28,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          quantity == 0
              ? GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: onRemove, color: AppTheme.emerald),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.add, size: 18), onPressed: onAdd, color: AppTheme.emerald),
                    ],
                  ),
                ),
        ],
      ),
    ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.itemCount, required this.subtotal, required this.loading, required this.onCheckout, required this.onClear});
  final int itemCount;
  final double subtotal;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$itemCount items', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('\u20B9${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.clear_all, color: Colors.white70), onPressed: onClear, tooltip: 'Clear cart'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.emerald,
                      ),
                      onPressed: loading ? null : onCheckout,
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Checkout'),
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

class _CheckoutResultSheet extends StatelessWidget {
  const _CheckoutResultSheet({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          FareRow(label: 'Subtotal', value: '\u20B9${result['subTotal']}'),
          FareRow(label: 'Delivery Fee', value: '\u20B9${result['deliveryFee']}'),
          if ((result['lateNightDriverBonus'] as num?)?.toDouble() != 0)
            FareRow(label: 'Late Night Driver Bonus', value: '\u20B9${result['lateNightDriverBonus']}'),
          FareRow(label: 'Platform Fee', value: '\u20B9${result['platformFee']}'),
          const Divider(),
          FareRow(label: 'Total', value: '\u20B9${result['totalAmount']}', bold: true),
          const SizedBox(height: 8),
          Text('Status: ${result['status']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
      ),
    );
  }
}

/// Swiggy-style cart summary bottom sheet with rounded top border.
/// Shows itemized cart contents, delivery address selector, payment method,
/// and bill details (including taxes) before confirming order.
class _CartSummarySheet extends StatefulWidget {
  const _CartSummarySheet({
    required this.items,
    required this.cart,
    required this.subtotal,
  });

  final List<dynamic> items;
  final Map<int, int> cart;
  final double subtotal;

  @override
  State<_CartSummarySheet> createState() => _CartSummarySheetState();
}

class _CartSummarySheetState extends State<_CartSummarySheet> {
  String _deliveryAddress = 'Current Location, Pondicherry';
  int _paymentMethod = 0; // 0 = Razorpay, 1 = Cash on Delivery

  static const _deliveryFee = 20.0;
  static const _platformFee = 5.0;

  double get _taxes => widget.subtotal * 0.05;
  double get _total => widget.subtotal + _deliveryFee + _platformFee + _taxes;

  Future<void> _changeAddress() async {
    final controller = TextEditingController(text: _deliveryAddress);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery Address'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your delivery address',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _deliveryAddress = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final subtotal = widget.subtotal;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text('Cart Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${cart.values.fold(0, (a, b) => a + b)} items',
                        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
                const Divider(height: 24),
                // Delivery Address selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: AppTheme.emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Delivery Address',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            Text(_deliveryAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _changeAddress,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Itemized list
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final entry = cart.entries.elementAt(i);
                      final item = widget.items[entry.key] as Map<String, dynamic>;
                      final name = item['name'] as String? ?? '';
                      final price = (item['price'] as num).toDouble();
                      final qty = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.emerald,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('\u20B9${(price * qty).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 24),
                // Payment method
                Text('Payment Method',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                RadioListTile<int>(
                  value: 0,
                  groupValue: _paymentMethod,
                  activeColor: AppTheme.emerald,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Razorpay (Online)'),
                  subtitle: const Text('UPI, Card, Net Banking'),
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 0),
                ),
                RadioListTile<int>(
                  value: 1,
                  groupValue: _paymentMethod,
                  activeColor: AppTheme.emerald,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cash on Delivery'),
                  subtitle: const Text('Pay with cash on arrival'),
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 1),
                ),
                const Divider(height: 24),
                // Bill details — 100% transparent breakdown
                _BillRow(label: 'Base Item Total', value: '\u20B9${subtotal.toStringAsFixed(0)}'),
                _BillRow(label: 'Taxes (GST 5%)', value: '\u20B9${_taxes.toStringAsFixed(0)}'),
                _BillRow(
                  label: 'Platform Fee',
                  value: '\u20B9${_platformFee.toStringAsFixed(0)}',
                  tooltip: 'This keeps the servers running without charging exorbitant merchant commissions.',
                ),
                _BillRow(
                  label: 'Driver Delivery Fee',
                  value: '\u20B9${_deliveryFee.toStringAsFixed(0)}',
                  badge: '100% to driver',
                  tooltip: 'The full delivery fee goes directly to the captain. PY Connect takes zero cut.',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('\u20B9${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                  ],
                ),
                const SizedBox(height: 20),
                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.emerald,
                    ),
                    onPressed: () => Navigator.pop(context, {
                      'confirmed': true,
                      'paymentMethod': _paymentMethod,
                      'deliveryAddress': _deliveryAddress,
                    }),
                    child: const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value, this.tooltip, this.badge});
  final String label;
  final String value;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.emerald),
                  ),
                ),
              ],
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  child: Icon(Icons.info_outline, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Item customization bottom sheet showing variants (radio), add-ons
/// (checkboxes), a quantity stepper, and an Add to Cart button.
class _ItemCustomizationSheet extends StatefulWidget {
  const _ItemCustomizationSheet({required this.item, required this.currentQty});

  final Map<String, dynamic> item;
  final int currentQty;

  @override
  State<_ItemCustomizationSheet> createState() => _ItemCustomizationSheetState();
}

class _ItemCustomizationSheetState extends State<_ItemCustomizationSheet> {
  late int _quantity;
  int? _selectedVariantIndex;
  final Set<int> _selectedAddOns = {};

  @override
  void initState() {
    super.initState();
    _quantity = 1;
  }

  List<Map<String, dynamic>> get _variants {
    final raw = widget.item['variants'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _addOns {
    final raw = widget.item['addOns'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  double get _basePrice => (widget.item['price'] as num).toDouble();

  double get _variantPrice {
    if (_selectedVariantIndex == null) return 0;
    final variants = _variants;
    if (_selectedVariantIndex! >= variants.length) return 0;
    return (variants[_selectedVariantIndex!]['price'] as num?)?.toDouble() ?? 0;
  }

  double get _addOnsPrice {
    double total = 0;
    for (final idx in _selectedAddOns) {
      total += (_addOns[idx]['price'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get _unitPrice => _basePrice + _variantPrice + _addOnsPrice;
  double get _totalPrice => _unitPrice * _quantity;

  @override
  Widget build(BuildContext context) {
    final variants = _variants;
    final addOns = _addOns;
    final name = widget.item['name'] as String? ?? '';
    final description = widget.item['description'] as String?;
    final imageUrl = widget.item['imageUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20, 12, 20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Item header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.restaurant_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                          const SizedBox(height: 6),
                          Text('\u20B9${_basePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.emerald)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                // Variants (radio buttons)
                if (variants.isNotEmpty) ...[
                  Text('Choose Size',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  for (int i = 0; i < variants.length; i++)
                    RadioListTile<int>(
                      value: i,
                      groupValue: _selectedVariantIndex,
                      activeColor: AppTheme.emerald,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(variants[i]['name'] as String? ?? 'Option ${i + 1}'),
                      subtitle: (variants[i]['price'] as num?)?.toDouble() != null &&
                              (variants[i]['price'] as num).toDouble() > 0
                          ? Text(
                              '+\u20B9${(variants[i]['price'] as num).toDouble().toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.emerald))
                          : null,
                      onChanged: (v) => setState(() => _selectedVariantIndex = v),
                    ),
                  const SizedBox(height: 8),
                ],
                // Add-ons (checkboxes)
                if (addOns.isNotEmpty) ...[
                  Text('Add-ons',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  for (int i = 0; i < addOns.length; i++)
                    CheckboxListTile(
                      value: _selectedAddOns.contains(i),
                      activeColor: AppTheme.emerald,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(addOns[i]['name'] as String? ?? 'Add-on ${i + 1}'),
                      subtitle: (addOns[i]['price'] as num?)?.toDouble() != null &&
                              (addOns[i]['price'] as num).toDouble() > 0
                          ? Text(
                              '+\u20B9${(addOns[i]['price'] as num).toDouble().toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.emerald))
                          : null,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedAddOns.add(i);
                          } else {
                            _selectedAddOns.remove(i);
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                ],
                const Divider(height: 24),
                // Quantity stepper + Add to Cart
                Row(
                  children: [
                    // Quantity stepper
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            color: AppTheme.emerald,
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Text('$_quantity',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            color: AppTheme.emerald,
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Add to Cart button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'quantity': _quantity,
                          'variantIndex': _selectedVariantIndex,
                          'addOnIndices': _selectedAddOns.toList(),
                          'unitPrice': _unitPrice,
                        });
                      },
                      child: Text(
                        'Add to Cart \u00B7 \u20B9${_totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

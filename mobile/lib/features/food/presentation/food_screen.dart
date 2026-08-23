import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/haptic.dart';
import '../../../core/animations/staggered_animations.dart';
import '../../../core/config/system_config.dart';
import '../../../core/design/design.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/razorpay_payment_service.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/quick_auth_sheet.dart';
import '../../checkout/cart_conflict_exception.dart';
import '../../checkout/cart_controller.dart';
import '../../checkout/presentation/floating_cart_pill.dart';
import '../../checkout/presentation/slide_to_pay.dart';
import '../../checkout/presentation/payment_success_overlay.dart';
import '../data/food_api.dart';
import 'widgets/item_customization_sheet.dart';
import '../../../core/widgets/menu_shimmer_grid.dart';

final menuProvider = FutureProvider.family<List<dynamic>, String>((ref, vendorId) async {
  final api = ref.watch(foodApiProvider);
  return await api.getMenu(vendorId);
});

class FoodScreen extends ConsumerStatefulWidget {
  const FoodScreen({
    super.key,
    required this.vendorId,
    this.vendorName,
    this.deliveryFee = 20.0,
  });

  final String vendorId;
  final String? vendorName;
  final double deliveryFee;

  @override
  ConsumerState<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends ConsumerState<FoodScreen> {
  bool _loading = false;
  String _searchQuery = '';
  String? _categoryFilter;

  /// Razorpay payment guard state.
  bool _paymentInProgress = false;
  Timer? _paymentGuardTimer;

  /// Last cart summary inputs so the checkout sheet can be reshown if the
  /// user cancels or the Razorpay flow errors out.
  List<dynamic>? _lastMenuItems;
  double _lastSubtotal = 0;

  /// Service category for the universal cart guard. All food items share
  /// this category so the cross-category guard only triggers when mixing
  /// food with essentials, transit, etc.
  static const _cartCategory = 'food';

  /// Extracts a stable identifier from a menu item map.
  /// Falls back to the item name when no `id` field is present.
  String _itemId(Map<String, dynamic> item) {
    return item['id'] as String? ?? item['name'] as String? ?? '';
  }

  /// Returns the quantity of [item] currently in the global cart, or 0.
  int _qtyInCart(CartState cart, Map<String, dynamic> item) {
    final id = _itemId(item);
    final match = cart.items.where((i) => i.id == id).firstOrNull;
    return match?.quantity ?? 0;
  }

  /// Builds a [CartItem] from a menu item map.
  /// [unitPrice] overrides the base price when the item has been customized
  /// with modifiers (base + selected modifier prices).
  /// [selectedModifierIds] and [selectedModifierNames] carry the modifier
  /// selections for backend validation and cart display.
  CartItem _toCartItem(
    Map<String, dynamic> item, {
    int quantity = 1,
    double? unitPrice,
    List<String>? selectedModifierIds,
    List<String>? selectedModifierNames,
  }) {
    return CartItem(
      id: _itemId(item),
      name: item['name'] as String? ?? '',
      price: unitPrice ?? (item['price'] as num).toDouble(),
      quantity: quantity,
      imageUrl: item['imageUrl'] as String?,
      category: item['category'] as String?,
      selectedModifierIds: selectedModifierIds ?? const [],
      selectedModifierNames: selectedModifierNames ?? const [],
    );
  }

  /// Attempts to add [item] to the global cart. If the cart already holds
  /// items from a different vendor or service category, shows a confirmation
  /// dialog and — on confirm — clears the cart and adds the new item.
  /// [unitPrice] overrides the base price for customized items.
  Future<void> _addToCart(
    Map<String, dynamic> item,
    int quantity, {
    double? unitPrice,
    List<String>? selectedModifierIds,
    List<String>? selectedModifierNames,
  }) async {
    final cartController = ref.read(cartProvider.notifier);
    final cartItem = _toCartItem(
      item,
      quantity: quantity,
      unitPrice: unitPrice,
      selectedModifierIds: selectedModifierIds,
      selectedModifierNames: selectedModifierNames,
    );

    try {
      cartController.addItem(
        item: cartItem,
        vendorId: widget.vendorId,
        vendorName: widget.vendorName ?? 'Menu',
        category: _cartCategory,
      );
    } on CartConflictException catch (e) {
      final confirmed = await _showCartConflictDialog(e.vendorName, e.newVendorName);
      if (confirmed == true) {
        cartController.clear();
        cartController.addItem(
          item: cartItem,
          vendorId: widget.vendorId,
          vendorName: widget.vendorName ?? 'Menu',
          category: _cartCategory,
        );
      }
    }
  }

  /// Shows the cross-vendor / cross-category confirmation dialog.
  Future<bool> _showCartConflictDialog(String vendorName, String newVendorName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace cart?'),
        content: const Text(
          'You have items from another vendor. Clear cart and add this item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear & Add'),
          ),
        ],
      ),
    );
    return confirmed == true;
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: AppTheme.night,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          AppHaptics.light();
          context.pop();
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          tooltip: 'Share restaurant',
          onPressed: () { _shareRestaurant(); },
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          tooltip: 'Order History',
          onPressed: () => context.push('/food/orders'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.vendorName ?? 'Menu',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
        ),
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
              fit: BoxFit.cover,
              fallbackIcon: Icons.restaurant,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuProvider(widget.vendorId));
    // Watch real-time vendor status so "Add to Cart" disables instantly
    // when the vendor toggles off accepting orders via SignalR.
    final statusMap = ref.watch(vendorAcceptingOrdersProvider);
    final isAcceptingOrders = statusMap[widget.vendorId] ?? true;

    // Watch the global cart so the UI reacts instantly to add / remove /
    // clear operations from any screen.
    final cartState = ref.watch(cartProvider);
    // Sync the legacy cartItemCountProvider so the home screen badge stays
    // in sync with the universal cart.
    ref.read(cartItemCountProvider.notifier).state = cartState.itemCount;

    // Only show the checkout bar if the cart belongs to this vendor.
    final isThisVendorCart =
        cartState.isNotEmpty && cartState.vendorId == widget.vendorId;
    final cartCount = isThisVendorCart ? cartState.itemCount : 0;
    final subtotal = isThisVendorCart ? cartState.subtotal : 0.0;


    return Scaffold(
      body: menuAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            const SliverFillRemaining(child: MenuShimmerGrid(itemCount: 8)),
          ],
        ),
        error: (e, _) => CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverFillRemaining(
              child: ErrorState(
                message: 'Could not load menu. Please try again.',
                onRetry: () => ref.invalidate(menuProvider(widget.vendorId)),
              ),
            ),
          ],
        ),
        data: (items) => _buildMenuSlivers(items, cartState, isAcceptingOrders, cartCount, subtotal),
      ),
    );

  }

  Widget _buildMenuSlivers(
    List<dynamic> items,
    CartState cartState,
    bool isAcceptingOrders,
    int cartCount,
    double subtotal,
  ) {
    final filtered = _filterItems(items);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => ref.refresh(menuProvider(widget.vendorId).future),
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isAcceptingOrders)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle, size: 20, color: AppTheme.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This restaurant is currently not accepting orders.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildPill('All', _categoryFilter == null, () {
                              AppHaptics.selection();
                              setState(() => _categoryFilter = null);
                            }),
                            ..._extractCategories(items).map((cat) => _buildPill(cat, _categoryFilter == cat, () {
                                  AppHaptics.selection();
                                  setState(() => _categoryFilter = cat);
                                })),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No items found',
                    subtitle: 'Try a different search or category.',
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: cartCount > 0 ? 90 : 16, top: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index] as Map<String, dynamic>;
                        final qty = _qtyInCart(cartState, item);
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
                            isEnabled: isAcceptingOrders,
                            onAdd: () {
                              AppHaptics.light();
                              final parsed = MenuItem.fromJson(item);
                              if (parsed.hasModifiers) {
                                _showCustomizationSheet(item, qty);
                              } else {
                                _addToCart(item, 1);
                              }
                            },
                            onRemove: () {
                              AppHaptics.light();
                              ref.read(cartProvider.notifier).decrementQuantity(_itemId(item));
                            },
                            onCardTap: () {
                              AppHaptics.light();
                              _showCustomizationSheet(item, qty);
                            },
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (cartCount > 0)
          FloatingCartPill(
            itemCount: cartCount,
            subtotal: subtotal,
            onCheckout: () {
              AppHaptics.medium();
              _showCartSummarySheet(items, subtotal);
            },
          ),
      ],
    );
  }

  Future<void> _showCustomizationSheet(
      Map<String, dynamic> item, int currentQty) async {
    // Parse the raw map into a typed MenuItem to check for modifier groups.
    final menuItem = MenuItem.fromJson(item);

    if (menuItem.hasModifiers) {
      // Item has modifier groups — use the new typed customization sheet.
      final result = await ItemCustomizationSheet.show(
        context,
        item: menuItem,
        initialQuantity: 1,
      );
      if (result != null && mounted) {
        await _addToCart(
          item,
          result.quantity,
          unitPrice: result.unitPrice,
          selectedModifierIds: result.selectedModifierIds,
          selectedModifierNames: result.selectedModifierNames,
        );
      }
      return;
    }

    // No modifier groups — fall back to the legacy variant/add-on sheet.
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemCustomizationSheet(item: item, currentQty: currentQty),
    );
    if (result != null && mounted) {
      AppHaptics.light();
      final qty = result['quantity'] as int? ?? 1;
      final unitPrice = (result['unitPrice'] as num?)?.toDouble();
      await _addToCart(item, qty, unitPrice: unitPrice);
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
    final cartState = ref.read(cartProvider);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSummarySheet(
        cartState: cartState,
        deliveryFee: widget.deliveryFee,
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
      final cartState = ref.read(cartProvider);
      final cartItems = cartState.items.map((item) {
        return {
          'name': item.name,
          'quantity': item.quantity,
          'unitPrice': item.price,
          if (item.selectedModifierIds.isNotEmpty)
            'selectedModifierIds': item.selectedModifierIds,
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

      // Use the backend-returned total if available; otherwise compute from
      // the transparent billing breakdown so the Razorpay payload matches
      // exactly what the user saw in the cart summary.
      final totalAmount = (result['totalAmount'] as num?)?.toDouble() ??
          cartState.grandTotal(widget.deliveryFee);
      final foodOrderId = result['orderId'] as String?;

      if (mounted) {
        if (paymentMethod == 1) {
          // Cash on Delivery — order is confirmed, safe to clear the cart
          ref.read(cartProvider.notifier).clear();
          final foodOrderId = result['orderId'] as String? ?? '';
          PaymentSuccessOverlay.show(
            context,
            amount: '₹${totalAmount.toStringAsFixed(0)}',
            orderId: foodOrderId,
            onComplete: () {
              if (!mounted) return;
              showModalBottomSheet(
                context: context,
                isDismissible: false,
                builder: (_) => _CheckoutResultSheet(result: result),
              );
            },
          );
        } else {
          // Razorpay — keep the cart until the backend confirms payment.
          _lastMenuItems = items;
          _lastSubtotal = subtotal;
          await _initiateRazorpayPayment(
            foodOrderId: foodOrderId,
            amount: totalAmount,
            orderResult: result,
          );
        }
      }
    } on CartPriceConflictException catch (e) {
      // Menu prices changed between cart creation and checkout.
      // Update the cart with live prices and prompt the user to review.
      if (mounted) {
        _handleCartPriceConflict(e, items, paymentMethod, deliveryAddress);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message.isNotEmpty ? e.message : 'Order failed. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Handles a cart price conflict (HTTP 409) by updating the cart with the
  /// live prices from the backend and showing a dialog prompting the user to
  /// review the new total before retrying checkout.
  Future<void> _handleCartPriceConflict(
    CartPriceConflictException conflict,
    List<dynamic> items,
    int paymentMethod,
    String? deliveryAddress,
  ) async {
    // Update the cart with the live prices from the backend.
    final cart = ref.read(cartProvider.notifier);
    final cartState = ref.read(cartProvider);
    for (final item in cartState.items) {
      final livePrice = conflict.liveItemPrices[item.name];
      if (livePrice != null && livePrice != item.price) {
        // Remove and re-add the item with the updated price.
        cart.removeItem(item.id);
        cart.addItem(
          item: item.copyWith(price: livePrice),
          vendorId: cartState.vendorId!,
          vendorName: cartState.vendorName!,
          category: cartState.category!,
        );
      }
    }

    // Show a dialog prompting the user to review the new total.
    final shouldRetry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Prices Updated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Menu prices have been updated by the restaurant. Please review your new total before paying.',
            ),
            const SizedBox(height: 16),
            Text(
              'New Total: \u20B9${conflict.liveTotalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.emerald,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Review & Pay'),
          ),
        ],
      ),
    );

    if (shouldRetry == true && mounted) {
      // Retry checkout with the updated cart prices.
      final newSubtotal = ref.read(cartProvider).subtotal;
      _checkout(items, newSubtotal,
          paymentMethod: paymentMethod, deliveryAddress: deliveryAddress);
    }
  }

  Future<void> _initiateRazorpayPayment({
    required String? foodOrderId,
    required double amount,
    required Map<String, dynamic> orderResult,
  }) async {
    final paymentService = ref.read(razorpayPaymentProvider);
    final authSession = ref.read(authControllerProvider).valueOrNull;

    setState(() => _paymentInProgress = true);
    _paymentGuardTimer?.cancel();
    _paymentGuardTimer = Timer(const Duration(minutes: 5), () {
      if (!_paymentInProgress) return;
      if (mounted) {
        setState(() => _paymentInProgress = false);
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Overlay may already be dismissed.
        }
        _showPaymentCancelledSnackBar();
        if (_lastMenuItems != null) {
          _showCartSummarySheet(_lastMenuItems!, _lastSubtotal);
        }
      }
    });

    try {
      final order = await paymentService.createOrder(
        amount: amount,
        foodOrderId: foodOrderId,
      );

      if (!mounted) return;

      // Show processing overlay while Razorpay checkout opens
      _showProcessingOverlay();

      // Wrap in a timeout so the app never freezes on the processing
      // spinner if the Razorpay SDK fails to fire a success/error event
      // (e.g. user dismisses the native sheet without triggering a
      // callback, or the SDK crashes).
      final paymentResult = await paymentService
          .startPayment(
            orderId: order.providerOrderId,
            amount: (amount * 100).round(), // paise
            phone: authSession?.phone ?? '',
            userName: authSession?.name,
          )
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () => PaymentError(
              code: -1,
              message: 'Payment timed out. Please try again.',
            ),
          );

      if (!mounted) return;
      _paymentGuardTimer?.cancel();
      setState(() => _paymentInProgress = false);
      Navigator.of(context, rootNavigator: true).pop(); // dismiss overlay

      switch (paymentResult) {
        case PaymentSuccess(:final paymentId, :final orderId, :final signature):
          // Verify payment signature on backend before confirming.
          final verified = await paymentService.verifyPayment(
            paymentId: order.paymentId,
            razorpayPaymentId: paymentId,
            razorpayOrderId: orderId,
            razorpaySignature: signature,
          );
          if (verified && mounted) {
            // Backend confirmed the payment — now it's safe to clear the cart.
            ref.read(cartProvider.notifier).clear();
            // Show the payment success overlay before navigating.
            final foodOrderId = orderResult['orderId'] as String? ?? '';
            PaymentSuccessOverlay.show(
              context,
              amount: '₹${orderResult['totalAmount']?.toStringAsFixed(0) ?? '0'}',
              orderId: foodOrderId,
              onComplete: () {
                if (!mounted) return;
                if (foodOrderId.isNotEmpty) {
                  context.push('/activity/food/$foodOrderId');
                }
              },
            );
          } else if (mounted) {
            _showPaymentCancelledSnackBar();
            if (_lastMenuItems != null) {
              _showCartSummarySheet(_lastMenuItems!, _lastSubtotal);
            }
          }
        case PaymentError(:final code, :final message):
          if (mounted) {
            _showPaymentCancelledSnackBar();
            if (_lastMenuItems != null) {
              _showCartSummarySheet(_lastMenuItems!, _lastSubtotal);
            }
          }
        case PaymentExternalWallet():
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('External wallet selected. Please complete payment.')),
            );
          }
      }
    } catch (e) {
      _paymentGuardTimer?.cancel();
      setState(() => _paymentInProgress = false);
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Overlay may already be dismissed.
        }
        _showPaymentCancelledSnackBar();
        if (_lastMenuItems != null) {
          _showCartSummarySheet(_lastMenuItems!, _lastSubtotal);
        }
      }
    }
  }

  Future<void> _shareRestaurant() async {
    final name = widget.vendorName ?? 'this restaurant';
    await Share.share(
      'Check out $name on PY Connect! https://pyconnect.run.place/restaurant/${widget.vendorId}',
      subject: name,
    );
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

  void _showPaymentCancelledSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment failed or cancelled. Please try again.'),
        duration: Duration(seconds: 4),
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
    this.isEnabled = true,
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
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
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
          // Text section (left, expanded)
          Expanded(
            child: Padding(
              // Right padding leaves room for the image + overlapping ADD button
              padding: const EdgeInsets.only(right: 12),
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
                      Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2))),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('\u20B9${price.toStringAsFixed(0)}', style: TextStyle(color: isDark ? const Color(0xE6FFFFFF) : AppTheme.charcoal, fontWeight: FontWeight.w700, fontSize: 15)),
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
          ),
          // Image + overlapping ADD button (Swiggy-style)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Item thumbnail (96x96 — Swiggy size)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? AppNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                                  : [const Color(0xFFF9FAFB), const Color(0xFFE5E7EB)],
                            ),
                          ),
                        ),
                ),
              ),
              // Floating ADD button — overlaps bottom edge of image
              if (quantity == 0)
                Positioned(
                  bottom: -10,
                  right: 8,
                  child: GestureDetector(
                    onTap: isEnabled ? onAdd : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEnabled
                              ? AppTheme.emerald
                              : AppTheme.emerald.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: isEnabled
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Text(
                        'ADD',
                        style: TextStyle(
                          color: isEnabled ? AppTheme.emerald : AppTheme.emerald.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: -10,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.emerald, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: isEnabled ? onRemove : null,
                          color: AppTheme.emerald,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: isEnabled ? onAdd : null,
                          color: AppTheme.emerald,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.itemCount, required this.subtotal, required this.loading, required this.onCheckout, required this.onClear, this.enabled = true});
  final int itemCount;
  final double subtotal;
  final bool loading;
  final VoidCallback onCheckout;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          gradient: enabled ? AppTheme.emeraldGradient : null,
          color: enabled ? null : Colors.grey,
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
                      onPressed: (loading || !enabled) ? null : onCheckout,
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
class _CartSummarySheet extends ConsumerStatefulWidget {
  const _CartSummarySheet({
    required this.cartState,
    required this.deliveryFee,
  });

  final CartState cartState;
  final double deliveryFee;

  @override
  ConsumerState<_CartSummarySheet> createState() => _CartSummarySheetState();
}

class _CartSummarySheetState extends ConsumerState<_CartSummarySheet> {
  String _deliveryAddress = 'Current Location, Pondicherry';
  int _paymentMethod = 0; // 0 = Razorpay, 1 = Cash on Delivery

  /// Whether Razorpay is active (from system config kill switches).
  /// If false, online payment options are hidden and COD is forced.
  bool get _isRazorpayActive {
    final config = ref.read(systemConfigProvider);
    return config.maybeWhen(
      data: (c) => c.isRazorpayActive,
      orElse: () => true,
    );
  }

  double get _subtotal => widget.cartState.subtotal;
  double get _taxes => widget.cartState.taxes;
  double get _platformFee => CartState.platformFee;
  double get _deliveryFee => widget.deliveryFee;
  double get _total => _subtotal + _taxes + _platformFee + _deliveryFee;

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
    final cartItems = widget.cartState.items;
    final subtotal = _subtotal;

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
                    Text('${widget.cartState.itemCount} items',
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
                    itemCount: cartItems.length,
                    itemBuilder: (_, i) {
                      final item = cartItems[i];
                      final name = item.name;
                      final price = item.price;
                      final qty = item.quantity;
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (item.selectedModifierNames.isNotEmpty)
                                    Text(
                                      item.selectedModifierNames.join(', '),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
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
                // Kill switch: hide Razorpay when IsRazorpayActive is false.
                // Force Cash on Delivery and show a maintenance banner.
                if (!_isRazorpayActive) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Online payments are currently undergoing maintenance. Cash only.',
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_isRazorpayActive)
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
                _BillRow(label: 'Item Total', value: '\u20B9${subtotal.toStringAsFixed(0)}'),
                _BillRow(label: 'Taxes (GST 5%)', value: '\u20B9${_taxes.toStringAsFixed(0)}'),
                _BillRow(
                  label: 'Platform Fee',
                  value: '\u20B9${_platformFee.toStringAsFixed(0)}',
                  tooltip: 'This keeps the servers running without charging exorbitant merchant commissions.',
                ),
                _BillRow(
                  label: 'Delivery Fee',
                  value: '\u20B9${_deliveryFee.toStringAsFixed(0)}',
                  badge: '100% to driver',
                  tooltip: 'The full delivery fee goes directly to the captain. PY Connect takes zero cut.',
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('\u20B9${_total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                  ],
                ),
                const SizedBox(height: 20),
                // Confirm button — SlideToPay for online, FilledButton for COD
                if (_paymentMethod == 0)
                  SlideToPay(
                    amount: '₹${_total.toStringAsFixed(0)}',
                    label: 'Slide to Pay',
                    onPay: () => Navigator.pop(context, {
                      'confirmed': true,
                      'paymentMethod': _paymentMethod,
                      'deliveryAddress': _deliveryAddress,
                    }),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      onPressed: () => Navigator.pop(context, {
                        'confirmed': true,
                        'paymentMethod': _paymentMethod,
                        'deliveryAddress': _deliveryAddress,
                      }),
                      child: const Text(
                        'Confirm Order',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(
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

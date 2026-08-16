import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single line item in the universal cart.
///
/// Each [CartItem] is scoped to a specific vendor and category so the
/// [CartController] can enforce the cross-vendor / cross-category guard.
class CartItem {
  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.category,
    this.selectedModifierIds = const [],
    this.selectedModifierNames = const [],
  });

  /// Unique identifier for the menu item (from the backend menu API).
  final String id;

  /// Display name shown in the cart summary.
  final String name;

  /// Unit price in rupees (already includes variant / add-on adjustments
  /// when the item was added via the customization sheet).
  final double price;

  /// Number of units ordered.
  final int quantity;

  /// Optional image URL for the item thumbnail.
  final String? imageUrl;

  /// The menu category this item belongs to (e.g. "Mains", "Beverages").
  /// Used by the cross-category guard.
  final String? category;

  /// IDs of selected modifiers (for backend order validation).
  final List<String> selectedModifierIds;

  /// Names of selected modifiers (for cart summary display).
  final List<String> selectedModifierNames;

  /// Returns a copy of this item with the supplied fields overridden.
  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? category,
    List<String>? selectedModifierIds,
    List<String>? selectedModifierNames,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      selectedModifierIds: selectedModifierIds ?? this.selectedModifierIds,
      selectedModifierNames: selectedModifierNames ?? this.selectedModifierNames,
    );
  }
}

/// Immutable snapshot of the cart at a point in time.
///
/// All items in a non-empty [CartState] belong to the same [vendorId] and
/// [category], enforced by [CartController].
class CartState {
  const CartState({
    this.items = const [],
    this.vendorId,
    this.vendorName,
    this.category,
  });

  final List<CartItem> items;
  final String? vendorId;
  final String? vendorName;
  final String? category;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Sum of every line item's `price * quantity`.
  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.price * item.quantity);

  /// Total number of individual units across all line items.
  int get itemCount =>
      items.fold(0, (sum, item) => sum + item.quantity);

  /// GST at 5% on the item subtotal.
  double get taxes => subtotal * 0.05;

  /// Flat platform fee.
  static const double platformFee = 5.0;

  /// Grand total = Item Total + Taxes + Platform Fee + Delivery Fee.
  ///
  /// [deliveryFee] is supplied by the caller because it varies per vendor
  /// and is not stored inside [CartState] (the cart is category-scoped, not
  /// vendor-scoped — the fee comes from the vendor record).
  double grandTotal(double deliveryFee) =>
      subtotal + taxes + platformFee + deliveryFee;
}

/// Result of an attempt to add an item to the cart.
///
/// The controller returns this instead of mutating state directly so the
/// UI layer can decide how to present the cross-vendor / cross-category
/// conflict to the user (dialog, snackbar, silent replace, etc.).
sealed class AddItemResult {
  const AddItemResult();
}

/// The item was added successfully with no conflict.
class AddItemSuccess extends AddItemResult {
  const AddItemSuccess();
}

/// The cart already contains items from a different vendor or category.
/// The UI should prompt the user; if they confirm, call
/// [CartController.clearAndAdd]; otherwise do nothing.
class AddItemConflict extends AddItemResult {
  const AddItemConflict({
    required this.item,
    required this.vendorId,
    required this.vendorName,
    required this.category,
  });

  final CartItem item;
  final String vendorId;
  final String vendorName;
  final String category;
}

/// Riverpod [StateNotifier] that manages the universal, cross-category cart.
///
/// Design decisions:
/// * The cart can only hold items from a **single vendor and category** at a
///   time. Attempting to add an item from a different vendor or category
///   produces an [AddItemConflict] that the UI resolves with a confirmation
///   dialog.
/// * State is immutable — every mutation produces a new [CartState].
/// * The cart does **not** store the delivery fee because that is a vendor
///   property, not a cart property. Callers pass it in when computing the
///   grand total.
class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  /// Attempts to add [item] to the cart.
  ///
  /// Returns [AddItemSuccess] if the item was added (either because the cart
  /// was empty, or the item belongs to the same vendor and category).
  /// Returns [AddItemConflict] if the cart already holds items from a
  /// different vendor or category — the caller should show a confirmation
  /// dialog and, on confirm, call [clearAndAdd] with the same arguments.
  AddItemResult addItem({
    required CartItem item,
    required String vendorId,
    required String vendorName,
    required String category,
  }) {
    // Empty cart — just set it.
    if (state.isEmpty) {
      state = CartState(
        items: [item],
        vendorId: vendorId,
        vendorName: vendorName,
        category: category,
      );
      return AddItemSuccess();
    }

    // Same vendor AND same category — merge into existing items.
    if (state.vendorId == vendorId && state.category == category) {
      final items = List<CartItem>.from(state.items);
      final existingIndex = items.indexWhere((i) => i.id == item.id);
      if (existingIndex >= 0) {
        items[existingIndex] = items[existingIndex].copyWith(
          quantity: items[existingIndex].quantity + item.quantity,
        );
      } else {
        items.add(item);
      }
      state = CartState(
        items: items,
        vendorId: vendorId,
        vendorName: vendorName,
        category: category,
      );
      return AddItemSuccess();
    }

    // Different vendor or category — conflict.
    return AddItemConflict(
      item: item,
      vendorId: vendorId,
      vendorName: vendorName,
      category: category,
    );
  }

  /// Clears the cart and adds [item] as the sole entry.
  /// Called by the UI after the user confirms an [AddItemConflict].
  void clearAndAdd({
    required CartItem item,
    required String vendorId,
    required String vendorName,
    required String category,
  }) {
    state = CartState(
      items: [item],
      vendorId: vendorId,
      vendorName: vendorName,
      category: category,
    );
  }

  /// Increments the quantity of the item with [itemId] by 1.
  void incrementQuantity(String itemId) {
    if (state.isEmpty) return;
    final items = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: item.quantity + 1);
      }
      return item;
    }).toList();
    state = CartState(
      items: items,
      vendorId: state.vendorId,
      vendorName: state.vendorName,
      category: state.category,
    );
  }

  /// Decrements the quantity of the item with [itemId] by 1.
  /// If the quantity drops to zero the item is removed entirely.
  void decrementQuantity(String itemId) {
    if (state.isEmpty) return;
    final items = <CartItem>[];
    for (final item in state.items) {
      if (item.id == itemId) {
        if (item.quantity > 1) {
          items.add(item.copyWith(quantity: item.quantity - 1));
        }
        // quantity == 1 → drop the item
      } else {
        items.add(item);
      }
    }
    state = CartState(
      items: items,
      vendorId: state.vendorId,
      vendorName: state.vendorName,
      category: state.category,
    );
  }

  /// Removes the item with [itemId] from the cart entirely.
  void removeItem(String itemId) {
    if (state.isEmpty) return;
    final items = state.items.where((i) => i.id != itemId).toList();
    state = CartState(
      items: items,
      vendorId: state.vendorId,
      vendorName: state.vendorName,
      category: state.category,
    );
  }

  /// Empties the cart completely.
  void clear() {
    state = const CartState();
  }
}

/// Global cart provider shared across all category screens (food, essentials,
/// etc.). Only one vendor/category's items can be in the cart at a time.
final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});

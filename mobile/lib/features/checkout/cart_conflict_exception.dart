/// Thrown by [CartController.addItem] when the user attempts to add an item
/// from a different vendor or service category than what is already in the
/// universal cart. The UI should catch this, prompt the user, and — if they
/// confirm — clear the cart and re-add the item.
class CartConflictException implements Exception {
  CartConflictException({
    required this.vendorName,
    required this.newVendorName,
    this.category,
    this.message = 'You have items from another vendor. Clear cart and add this item?',
  });

  /// Name of the vendor already present in the cart.
  final String vendorName;

  /// Name of the vendor whose item is being added.
  final String newVendorName;

  /// Optional service category being added, for context.
  final String? category;

  /// Human-readable message describing the conflict.
  final String message;

  @override
  String toString() => message;
}

import '../../../core/network/api_client.dart';

/// A single selectable modifier within a [ModifierGroup].
class Modifier {
  const Modifier({
    required this.id,
    required this.modifierGroupId,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.sortOrder,
  });

  final String id;
  final String modifierGroupId;
  final String name;
  final double price;
  final bool isAvailable;
  final int sortOrder;

  factory Modifier.fromJson(Map<String, dynamic> json) {
    return Modifier(
      id: json['id'] as String? ?? '',
      modifierGroupId: json['modifierGroupId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isAvailable: json['isAvailable'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A group of modifiers for a menu item (e.g. "Choose Size", "Extra Toppings").
class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.minSelections,
    required this.maxSelections,
    required this.sortOrder,
    required this.isRequired,
    required this.modifiers,
  });

  final String id;
  final String menuItemId;
  final String name;
  final int minSelections;
  final int maxSelections;
  final int sortOrder;
  final bool isRequired;
  final List<Modifier> modifiers;

  /// True when this group is single-choice (exactly one selection required).
  bool get isSingleChoice => minSelections == 1 && maxSelections == 1;

  /// True when this group is multi-choice (optional, up to [maxSelections]).
  bool get isMultiChoice => minSelections == 0 && maxSelections > 0;

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final modsRaw = json['modifiers'] as List? ?? [];
    return ModifierGroup(
      id: json['id'] as String? ?? '',
      menuItemId: json['menuItemId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      minSelections: (json['minSelections'] as num?)?.toInt() ?? 0,
      maxSelections: (json['maxSelections'] as num?)?.toInt() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isRequired: json['isRequired'] as bool? ?? false,
      modifiers: modsRaw
          .whereType<Map<String, dynamic>>()
          .map(Modifier.fromJson)
          .toList(),
    );
  }
}

/// A menu item with its modifier groups loaded from the backend.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.modifierGroups,
    this.description,
    this.category,
    this.isAvailable = true,
    this.isLateNight = false,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final List<ModifierGroup> modifierGroups;
  final String? description;
  final String? category;
  final bool isAvailable;
  final bool isLateNight;
  final String? imageUrl;

  /// True when this item has at least one modifier group.
  bool get hasModifiers => modifierGroups.isNotEmpty;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final groupsRaw = json['modifierGroups'] as List? ?? [];
    return MenuItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
      category: json['category'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isLateNight: json['isLateNight'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      modifierGroups: groupsRaw
          .whereType<Map<String, dynamic>>()
          .map(ModifierGroup.fromJson)
          .toList(),
    );
  }
}

class FoodDeliveryApi {
  FoodDeliveryApi(this._api);
  final ApiClient _api;

  Future<List<dynamic>> getMenu(String vendorId) async {
    return await _api.get('/api/vendors/$vendorId/menu') as List<dynamic>;
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> body) async {
    return await _api.post('/api/orders/checkout', data: body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(String orderId) async {
    return await _api.get('/api/orders/$orderId') as Map<String, dynamic>;
  }

  Future<List<dynamic>> listOrders({int page = 1, int pageSize = 20}) async {
    return await _api.get('/api/orders', queryParameters: {'page': page, 'pageSize': pageSize}) as List<dynamic>;
  }

  /// Cancels a food order. Only works if the order is still in "Pending"
  /// status (before the restaurant accepts it on the KDS). Returns the
  /// updated order with cancellation details.
  Future<Map<String, dynamic>> cancelOrder(String orderId, {String? reason}) async {
    return await _api.post('/api/orders/$orderId/cancel', data: {
      if (reason != null) 'reason': reason,
    }) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listVendors({bool foodVendorsOnly = false}) async {
    return await _api.get('/api/vendors',
        queryParameters: {'foodVendorsOnly': foodVendorsOnly}) as List<dynamic>;
  }
}

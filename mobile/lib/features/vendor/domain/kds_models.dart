/// KDS order stage progression.
enum KdsStage {
  incoming,
  preparing,
  ready,
  completed;

  String get label => switch (this) {
        incoming => 'Incoming',
        preparing => 'Preparing',
        ready => 'Ready',
        completed => 'Completed',
      };

  int get order => switch (this) {
        incoming => 0,
        preparing => 1,
        ready => 2,
        completed => 3,
      };

  KdsStage? get next => switch (this) {
        incoming => preparing,
        preparing => ready,
        ready => completed,
        completed => null,
      };
}

/// A single KDS order with items and timing.
class KdsOrder {
  KdsOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.stage,
    required this.items,
    required this.placedAt,
    required this.vendorName,
    this.deliveryAddress,
    this.notes,
  });

  factory KdsOrder.fromJson(Map<String, dynamic> json) => KdsOrder(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String? ?? '',
        customerName: json['customerName'] as String? ?? 'Guest',
        stage: KdsStage.values.firstWhere(
          (s) => s.name == (json['stage'] as String? ?? 'incoming'),
          orElse: () => KdsStage.incoming,
        ),
        items: (json['items'] as List? ?? [])
            .map((e) => KdsOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        placedAt: DateTime.tryParse(json['placedAt'] as String? ?? '') ??
            DateTime.now(),
        vendorName: json['vendorName'] as String? ?? '',
        deliveryAddress: json['deliveryAddress'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final String orderNumber;
  final String customerName;
  final KdsStage stage;
  final List<KdsOrderItem> items;
  final DateTime placedAt;
  final String vendorName;
  final String? deliveryAddress;
  final String? notes;

  /// Elapsed minutes since order was placed.
  int get elapsedMinutes => DateTime.now().difference(placedAt).inMinutes;

  /// Urgency level based on elapsed time.
  /// Green <10min, Amber 10-20min, Red >20min per MasterPlan spec.
  KdsUrgency get urgency {
    final mins = elapsedMinutes;
    if (mins > 20) return KdsUrgency.critical;
    if (mins > 10) return KdsUrgency.warning;
    return KdsUrgency.normal;
  }
}

/// A single item within a KDS order.
class KdsOrderItem {
  KdsOrderItem({
    required this.name,
    required this.quantity,
    this.id = '',
    this.specialInstructions,
  });

  factory KdsOrderItem.fromJson(Map<String, dynamic> json) => KdsOrderItem(
        id: (json['id'] ?? json['itemId']) as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        specialInstructions: json['specialInstructions'] as String?,
      );

  /// Backend item identifier used for partial-refund calls. May be empty
  /// if the backend payload omits it (older deployments).
  final String id;
  final String name;
  final int quantity;
  final String? specialInstructions;
}

/// Urgency level for color-coding KDS cards.
enum KdsUrgency {
  normal,
  warning,
  critical;
}

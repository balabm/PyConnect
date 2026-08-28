import '../../../core/network/api_client.dart';

/// API client for PY Prime subscription management.
class SubscriptionApi {
  SubscriptionApi(this._api);

  final ApiClient _api;

  /// Gets the current user's PY Prime status.
  Future<PrimeStatusModel> getStatus() async {
    final body = await _api.get('/api/subscriptions/status');
    return PrimeStatusModel.fromJson(body as Map<String, dynamic>);
  }

  /// Creates a Razorpay order for a PY Prime monthly subscription.
  Future<SubscriptionOrderResult> createOrder() async {
    final body = await _api.post('/api/subscriptions/create-order');
    return SubscriptionOrderResult.fromJson(body as Map<String, dynamic>);
  }

  /// Activates PY Prime after successful Razorpay payment.
  Future<PrimeStatusModel> activate(String paymentReference) async {
    final body = await _api.post('/api/subscriptions/activate', data: {
      'paymentReference': paymentReference,
    });
    return PrimeStatusModel.fromJson(body as Map<String, dynamic>);
  }
}

class PrimeStatusModel {
  PrimeStatusModel({
    required this.isPrime,
    this.expiresAt,
    required this.inGracePeriod,
    required this.gracePeriodDays,
    required this.monthlyPrice,
  });

  factory PrimeStatusModel.fromJson(Map<String, dynamic> json) =>
      PrimeStatusModel(
        isPrime: json['isPrime'] as bool? ?? false,
        expiresAt: json['expiresAt'] as String?,
        inGracePeriod: json['inGracePeriod'] as bool? ?? false,
        gracePeriodDays: json['gracePeriodDays'] as int? ?? 0,
        monthlyPrice: (json['monthlyPrice'] as num?)?.toDouble() ?? 149,
      );

  final bool isPrime;
  final String? expiresAt;
  final bool inGracePeriod;
  final int gracePeriodDays;
  final double monthlyPrice;
}

class SubscriptionOrderResult {
  SubscriptionOrderResult({required this.razorpayOrderId, required this.amount});

  factory SubscriptionOrderResult.fromJson(Map<String, dynamic> json) =>
      SubscriptionOrderResult(
        razorpayOrderId: json['razorpayOrderId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );

  final String razorpayOrderId;
  final double amount;
}

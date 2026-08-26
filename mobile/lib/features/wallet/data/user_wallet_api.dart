import '../../../core/network/api_client.dart';

/// API client for the consumer PY Wallet.
class UserWalletApi {
  UserWalletApi(this._api);

  final ApiClient _api;

  /// Fetches the current user's wallet balance breakdown via
  /// GET /api/user/wallet.
  Future<UserWalletModel> getWallet() async {
    final body = await _api.get('/api/user/wallet');
    return UserWalletModel.fromJson(body as Map<String, dynamic>);
  }

  /// Initiates a wallet top-up by creating a Razorpay order.
  /// Returns the Razorpay order ID to use for checkout.
  Future<TopUpInitResult> initiateTopUp(double amount) async {
    final body = await _api.post('/api/user/wallet/topup', data: {
      'amount': amount,
    });
    return TopUpInitResult.fromJson(body as Map<String, dynamic>);
  }

  /// Confirms a wallet top-up after successful Razorpay checkout.
  /// Verifies the payment signature and credits the real balance.
  Future<UserWalletModel> confirmTopUp({
    required double amount,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    final body = await _api.post('/api/user/wallet/topup/confirm', data: {
      'amount': amount,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'signature': signature,
    });
    return UserWalletModel.fromJson(body as Map<String, dynamic>);
  }
}

class UserWalletModel {
  UserWalletModel({
    required this.promoBalance,
    required this.realBalance,
    required this.pyCoins,
    required this.totalBalance,
  });

  factory UserWalletModel.fromJson(Map<String, dynamic> json) =>
      UserWalletModel(
        promoBalance: (json['promoBalance'] as num?)?.toDouble() ?? 0,
        realBalance: (json['realBalance'] as num?)?.toDouble() ?? 0,
        pyCoins: (json['pyCoins'] as num?)?.toInt() ?? 0,
        totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0,
      );

  final double promoBalance;
  final double realBalance;
  final int pyCoins;
  final double totalBalance;
}

class TopUpInitResult {
  TopUpInitResult({required this.razorpayOrderId, required this.amount});

  factory TopUpInitResult.fromJson(Map<String, dynamic> json) => TopUpInitResult(
        razorpayOrderId: json['razorpayOrderId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );

  final String razorpayOrderId;
  final double amount;
}

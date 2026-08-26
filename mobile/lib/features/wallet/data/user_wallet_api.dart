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

  /// Fetches the user's recent wallet transactions.
  Future<List<UserWalletTransactionModel>> getTransactions({int limit = 50}) async {
    final body = await _api.get('/api/user/wallet/transactions',
        queryParameters: {'limit': limit});
    final list = body as List? ?? [];
    return list
        .map((e) => UserWalletTransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
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

class UserWalletTransactionModel {
  UserWalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory UserWalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      UserWalletTransactionModel(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'TopUp',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        referenceId: json['referenceId'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );

  final String id;
  final String type;
  final double amount;
  final String description;
  final String? referenceId;
  final String createdAt;

  bool get isCredit => amount > 0;
}

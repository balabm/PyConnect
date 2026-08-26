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

import '../../../core/network/api_client.dart';

/// API client for the consumer referral program.
class ReferralApi {
  ReferralApi(this._api);

  final ApiClient _api;

  /// Fetches the current user's referral code and stats.
  Future<ReferralInfoModel> getMyReferralInfo() async {
    final body = await _api.get('/api/referrals/me');
    return ReferralInfoModel.fromJson(body as Map<String, dynamic>);
  }

  /// Applies a referral code during onboarding.
  Future<ApplyReferralResult> applyReferralCode(String code) async {
    final body = await _api.post('/api/referrals/apply', data: {
      'referralCode': code,
    });
    return ApplyReferralResult.fromJson(body as Map<String, dynamic>);
  }
}

class ReferralInfoModel {
  ReferralInfoModel({
    required this.referralCode,
    required this.totalReferred,
    required this.completed,
    required this.pending,
    required this.totalEarned,
  });

  factory ReferralInfoModel.fromJson(Map<String, dynamic> json) =>
      ReferralInfoModel(
        referralCode: json['referralCode'] as String? ?? '',
        totalReferred: json['totalReferred'] as int? ?? 0,
        completed: json['completed'] as int? ?? 0,
        pending: json['pending'] as int? ?? 0,
        totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      );

  final String referralCode;
  final int totalReferred;
  final int completed;
  final int pending;
  final double totalEarned;
}

class ApplyReferralResult {
  ApplyReferralResult({required this.success, required this.message});

  factory ApplyReferralResult.fromJson(Map<String, dynamic> json) =>
      ApplyReferralResult(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );

  final bool success;
  final String message;
}

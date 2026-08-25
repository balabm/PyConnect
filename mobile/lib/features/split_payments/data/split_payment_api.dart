import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

final splitPaymentApiProvider = Provider<SplitPaymentApi>((ref) {
  return SplitPaymentApi(ref.read(apiClientProvider));
});

class SplitPaymentPoolModel {
  SplitPaymentPoolModel({
    required this.id,
    required this.totalAmount,
    required this.collectedAmount,
    required this.description,
    required this.deepLinkSlug,
    required this.deepLinkUrl,
    required this.status,
    required this.perShareAmount,
    required this.maxShares,
    required this.claimedShares,
    required this.expiresAt,
    required this.contributors,
  });

  factory SplitPaymentPoolModel.fromJson(Map<String, dynamic> json) =>
      SplitPaymentPoolModel(
        id: json['id'] as String,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        collectedAmount: (json['collectedAmount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        deepLinkSlug: json['deepLinkSlug'] as String? ?? '',
        deepLinkUrl: json['deepLinkUrl'] as String? ?? '',
        status: json['status'] as String? ?? 'Active',
        perShareAmount: (json['perShareAmount'] as num?)?.toDouble() ?? 0,
        maxShares: json['maxShares'] as int? ?? 0,
        claimedShares: json['claimedShares'] as int? ?? 0,
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now(),
        contributors: ((json['contributors'] as List?) ?? [])
            .map((e) => SplitContributorModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final double totalAmount;
  final double collectedAmount;
  final String description;
  final String deepLinkSlug;
  final String deepLinkUrl;
  final String status;
  final double perShareAmount;
  final int maxShares;
  final int claimedShares;
  final DateTime expiresAt;
  final List<SplitContributorModel> contributors;

  bool get isActive => status == 'Active';
  bool get isFullyPaid => status == 'FullyPaid';
  double get progress => totalAmount > 0 ? (collectedAmount / totalAmount).clamp(0.0, 1.0) : 0;
  int get sharesLeft => maxShares - claimedShares;
}

class SplitContributorModel {
  SplitContributorModel({
    required this.userId,
    required this.name,
    required this.shareAmount,
    required this.paidAmount,
    required this.status,
  });

  factory SplitContributorModel.fromJson(Map<String, dynamic> json) =>
      SplitContributorModel(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'Anonymous',
        shareAmount: (json['shareAmount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Pending',
      );

  final String userId;
  final String name;
  final double shareAmount;
  final double paidAmount;
  final String status;

  bool get isPaid => status == 'Paid';
}

class SplitPaymentApi {
  SplitPaymentApi(this._api);

  final ApiClient _api;

  Future<SplitPaymentPoolModel> createPool({
    required double totalAmount,
    required String description,
    required int maxShares,
    String? referenceType,
    String? referenceId,
    int? expiresAtHours,
  }) async {
    final body = await _api.post('/api/split-payments', data: {
      'totalAmount': totalAmount,
      'description': description,
      'maxShares': maxShares,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'expiresAtHours': expiresAtHours ?? 72,
    });
    return SplitPaymentPoolModel.fromJson(body as Map<String, dynamic>);
  }

  Future<SplitPaymentPoolModel> getBySlug(String slug) async {
    final body = await _api.get('/api/split-payments/$slug');
    return SplitPaymentPoolModel.fromJson(body as Map<String, dynamic>);
  }

  Future<void> claimShare(String poolId) async {
    await _api.post('/api/split-payments/$poolId/claim');
  }

  Future<void> payShare({
    required String poolId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _api.post('/api/split-payments/$poolId/pay', data: {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
  }

  Future<List<SplitPaymentPoolModel>> myPools() async {
    final body = await _api.get('/api/split-payments/my-pools');
    final list = body as List? ?? [];
    return list
        .map((e) => SplitPaymentPoolModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelPool(String poolId) async {
    await _api.post('/api/split-payments/$poolId/cancel');
  }
}

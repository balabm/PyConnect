import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class TicketValidationResult {
  TicketValidationResult({
    required this.isValid,
    required this.serviceType,
    required this.userName,
    required this.message,
    this.isDuplicate = false,
    this.previousScanAt,
    this.guestCount = 0,
    this.coverChargeAmount = 0,
    this.creditUsed = 0,
    this.bookingId,
    this.loyaltyTier,
    this.visitsThisMonth = 0,
    this.lifetimeValue = 0,
  });

  factory TicketValidationResult.fromJson(Map<String, dynamic> json) =>
      TicketValidationResult(
        isValid: json['isValid'] as bool,
        serviceType: json['serviceType'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isDuplicate: json['isDuplicate'] as bool? ?? false,
        previousScanAt: json['previousScanAt'] as String?,
        guestCount: json['guestCount'] as int? ?? 0,
        coverChargeAmount: (json['coverChargeAmount'] as num?)?.toDouble() ?? 0,
        creditUsed: (json['creditUsed'] as num?)?.toDouble() ?? 0,
        bookingId: json['bookingId'] as String?,
        loyaltyTier: json['loyaltyTier'] as String?,
        visitsThisMonth: json['visitsThisMonth'] as int? ?? 0,
        lifetimeValue: (json['lifetimeValue'] as num?)?.toDouble() ?? 0,
      );

  final bool isValid;
  final String serviceType;
  final String userName;
  final String message;
  final bool isDuplicate;
  final String? previousScanAt;
  final int guestCount;
  final double coverChargeAmount;
  final double creditUsed;
  final String? bookingId;
  final String? loyaltyTier;
  final int visitsThisMonth;
  final double lifetimeValue;

  /// Whether this guest is a VIP (top 5% spender at this venue).
  /// In demo mode, this is simulated — every 3rd scan is treated as VIP
  /// to demonstrate the gold overlay during pitches.
  bool get isVip => loyaltyTier?.toLowerCase() == 'vip' || loyaltyTier?.toLowerCase() == 'whale';
}

class ScannerApi {
  ScannerApi(this._api);

  final ApiClient _api;
  int _demoScanCount = 0;

  Future<TicketValidationResult> validateTicket(String qrPayload) async {
    try {
      final body = await _api.post(
        '/api/vendor/validate-ticket',
        data: {'qrPayload': qrPayload},
      );
      var result = TicketValidationResult.fromJson(body as Map<String, dynamic>);

      // Demo-mode VIP simulation: every 3rd valid scan is treated as a VIP
      // to demonstrate the gold overlay during pitches. In production, the
      // backend sets loyaltyTier based on actual spend history.
      if (AppConfig.isDemoMode && result.isValid && _demoScanCount % 3 == 2) {
        result = TicketValidationResult(
          isValid: true,
          serviceType: result.serviceType,
          userName: result.userName,
          message: result.message,
          guestCount: result.guestCount,
          coverChargeAmount: result.coverChargeAmount,
          creditUsed: result.creditUsed,
          bookingId: result.bookingId,
          loyaltyTier: 'VIP',
          visitsThisMonth: 7,
          lifetimeValue: 45000,
        );
      }
      _demoScanCount++;
      return result;
    } on ApiException catch (e) {
      final msg = e.message.toLowerCase();
      final isDuplicate = msg.contains('already');
      return TicketValidationResult(
        isValid: false,
        isDuplicate: isDuplicate,
        serviceType: '',
        userName: '',
        message: e.message,
      );
    }
  }
}

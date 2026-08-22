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
}

class ScannerApi {
  ScannerApi(this._api);

  final ApiClient _api;

  Future<TicketValidationResult> validateTicket(String qrPayload) async {
    try {
      final body = await _api.post(
        '/api/vendor/validate-ticket',
        data: {'qrPayload': qrPayload},
      );
      return TicketValidationResult.fromJson(body as Map<String, dynamic>);
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

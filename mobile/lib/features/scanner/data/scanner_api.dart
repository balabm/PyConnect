import '../../../core/network/api_client.dart';

class TicketValidationResult {
  TicketValidationResult({
    required this.isValid,
    required this.serviceType,
    required this.userName,
    required this.message,
    this.isDuplicate = false,
    this.previousScanAt,
  });

  factory TicketValidationResult.fromJson(Map<String, dynamic> json) =>
      TicketValidationResult(
        isValid: json['isValid'] as bool,
        serviceType: json['serviceType'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isDuplicate: json['isDuplicate'] as bool? ?? false,
        previousScanAt: json['previousScanAt'] as String?,
      );

  final bool isValid;
  final String serviceType;
  final String userName;
  final String message;
  final bool isDuplicate;
  final String? previousScanAt;
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

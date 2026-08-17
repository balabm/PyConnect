import '../../../core/network/api_client.dart';
import '../../scanner/data/scanner_api.dart';

class Vendor {
  Vendor({
    required this.id,
    required this.name,
    required this.category,
    this.contactPhone,
    this.merchantReference,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        contactPhone: json['contactPhone'] as String?,
        merchantReference: json['merchantReference'] as String?,
      );

  final String id;
  final String name;
  final String category;
  final String? contactPhone;
  final String? merchantReference;
}

class VendorApi {
  VendorApi(this._api);

  final ApiClient _api;

  Future<List<Vendor>> list({String? category}) async {
    final body = await _api.get(
      '/api/vendors',
      queryParameters: {
        if (category != null) 'category': category,
      },
    );
    return (body as List)
        .map((e) => Vendor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TicketValidationResult> validateTicket(String code) async {
    final body = await _api.post(
      '/api/vendor/validate-ticket',
      data: {'qrPayload': code},
    );
    return TicketValidationResult.fromJson(body as Map<String, dynamic>);
  }
}
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

  /// Fetches all checked-in bookings (live tables) for the authenticated
  /// vendor. Each entry includes the guest name, guest count, cover charge
  /// amount, and available credit. Used by the Partner app's "Live Tables"
  /// tab so waitstaff can track prepaid cover charge against the final bill.
  Future<List<LiveTableEntry>> getLiveTables() async {
    final body = await _api.get('/api/vendor/live-tables');
    final list = body as List<dynamic>;
    return list
        .map((e) => LiveTableEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// A single live table entry — a checked-in booking with prepaid cover
/// charge credit available for the waitstaff to track.
class LiveTableEntry {
  LiveTableEntry({
    required this.bookingId,
    required this.guestName,
    required this.guestCount,
    required this.coverChargeAmount,
    required this.creditUsed,
    required this.creditAvailable,
    required this.serviceType,
    required this.checkedInAt,
    required this.status,
  });

  factory LiveTableEntry.fromJson(Map<String, dynamic> json) => LiveTableEntry(
        bookingId: json['bookingId'] as String,
        guestName: json['guestName'] as String? ?? 'Unknown',
        guestCount: json['guestCount'] as int? ?? 0,
        coverChargeAmount: (json['coverChargeAmount'] as num).toDouble(),
        creditUsed: (json['creditUsed'] as num?)?.toDouble() ?? 0,
        creditAvailable: (json['creditAvailable'] as num?)?.toDouble() ?? 0,
        serviceType: json['serviceType'] as String? ?? '',
        checkedInAt: DateTime.parse(json['checkedInAt'] as String),
        status: json['status'] as String? ?? '',
      );

  final String bookingId;
  final String guestName;
  final int guestCount;
  final double coverChargeAmount;
  final double creditUsed;
  final double creditAvailable;
  final String serviceType;
  final DateTime checkedInAt;
  final String status;
}
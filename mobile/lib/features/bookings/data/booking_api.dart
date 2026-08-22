import '../../../core/network/api_client.dart';

class BookingResult {
  BookingResult({
    required this.bookingId,
    required this.status,
    required this.amount,
    required this.passToken,
  });

  factory BookingResult.fromJson(Map<String, dynamic> json) => BookingResult(
        bookingId: json['bookingId'] as String,
        status: json['status'] as String,
        amount: (json['amount'] as num).toDouble(),
        passToken: json['passToken'] as String? ?? '',
      );

  final String bookingId;
  final String status;
  final double amount;
  final String passToken;
}

/// Detailed ticket response from GET /api/bookings/{id}/ticket.
/// Includes the cryptographically signed QR pass token and booking details
/// needed to render the anti-screenshot ticket screen.
class TicketDto {
  TicketDto({
    required this.bookingId,
    required this.passToken,
    required this.serviceType,
    required this.status,
    required this.totalAmount,
    required this.seatCount,
    required this.venueName,
    required this.scheduledFor,
    this.notes,
  });

  factory TicketDto.fromJson(Map<String, dynamic> json) => TicketDto(
        bookingId: json['bookingId'] as String,
        passToken: json['passToken'] as String? ?? '',
        serviceType: json['serviceType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        totalAmount: (json['totalAmount'] as num).toDouble(),
        seatCount: json['seatCount'] as int? ?? 0,
        venueName: json['venueName'] as String? ?? 'Venue',
        scheduledFor: DateTime.parse(json['scheduledFor'] as String),
        notes: json['notes'] as String?,
      );

  final String bookingId;
  final String passToken;
  final String serviceType;
  final String status;
  final double totalAmount;
  final int seatCount;
  final String venueName;
  final DateTime scheduledFor;
  final String? notes;
}

class BookingApi {
  BookingApi(this._api);

  final ApiClient _api;

  Future<BookingResult> create({
    required String venueId,
    required int seats,
    required DateTime scheduledFor,
    String? notes,
  }) async {
    final body = await _api.post(
      '/api/bookings',
      data: {
        'venueId': venueId,
        'seats': seats,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        'notes': notes,
      },
    );
    return BookingResult.fromJson(body as Map<String, dynamic>);
  }

  /// Fetches the signed QR pass token and booking details for the
  /// consumer's ticket screen.
  Future<TicketDto> getTicket(String bookingId) async {
    final body = await _api.get('/api/bookings/$bookingId/ticket');
    return TicketDto.fromJson(body as Map<String, dynamic>);
  }
}
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
}
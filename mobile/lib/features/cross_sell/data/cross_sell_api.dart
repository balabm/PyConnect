import '../../../core/network/api_client.dart';

/// API client for cross-sell ride upsell suggestions.
class CrossSellApi {
  CrossSellApi(this._api);

  final ApiClient _api;

  /// Gets a ride upsell suggestion for a confirmed booking.
  Future<RideUpsellSuggestionModel?> getRideUpsell(String bookingId) async {
    try {
      final body = await _api.get('/api/cross-sell/ride-upsell/$bookingId');
      return RideUpsellSuggestionModel.fromJson(body as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class RideUpsellSuggestionModel {
  RideUpsellSuggestionModel({
    required this.bookingId,
    required this.venueName,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.pickupTime,
    required this.eventTime,
    required this.discountPercent,
    required this.discountText,
  });

  factory RideUpsellSuggestionModel.fromJson(Map<String, dynamic> json) =>
      RideUpsellSuggestionModel(
        bookingId: json['bookingId'] as String? ?? '',
        venueName: json['venueName'] as String? ?? '',
        dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble() ?? 0,
        dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble() ?? 0,
        pickupTime: json['pickupTime'] as String? ?? '',
        eventTime: json['eventTime'] as String? ?? '',
        discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
        discountText: json['discountText'] as String? ?? '',
      );

  final String bookingId;
  final String venueName;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String pickupTime;
  final String eventTime;
  final double discountPercent;
  final String discountText;
}

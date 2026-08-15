import '../../../core/network/api_client.dart';

class Homestay {
  Homestay({
    required this.id,
    required this.name,
    required this.description,
    required this.locationArea,
    required this.latitude,
    required this.longitude,
    required this.nightlyRate,
    required this.maxGuests,
    required this.hasWifi,
    required this.isVerified,
  });

  factory Homestay.fromJson(Map<String, dynamic> json) => Homestay(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        locationArea: json['locationArea'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        nightlyRate: (json['nightlyRate'] as num).toDouble(),
        maxGuests: (json['maxGuests'] as num).toInt(),
        hasWifi: json['hasWifi'] as bool,
        isVerified: json['isVerified'] as bool,
      );

  final String id;
  final String name;
  final String description;
  final String locationArea;
  final double latitude;
  final double longitude;
  final double nightlyRate;
  final int maxGuests;
  final bool hasWifi;
  final bool isVerified;
}

class AddOnSuggestion {
  AddOnSuggestion({
    required this.name,
    required this.description,
    required this.price,
    required this.isFree,
    required this.discountPercentage,
  });

  factory AddOnSuggestion.fromJson(Map<String, dynamic> json) => AddOnSuggestion(
        name: json['name'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        isFree: json['isFree'] as bool,
        discountPercentage: (json['discountPercentage'] as num).toDouble(),
      );

  final String name;
  final String description;
  final double price;
  final bool isFree;
  final double discountPercentage;
}

class BookHomestayRequest {
  BookHomestayRequest({
    required this.homestayId,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    this.addScooterPickup = false,
    this.addLuggageCloak = false,
  });

  final String homestayId;
  final String checkIn;
  final String checkOut;
  final int guests;
  final bool addScooterPickup;
  final bool addLuggageCloak;

  Map<String, dynamic> toJson() => {
        'homestayId': homestayId,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'guests': guests,
        'addScooterPickup': addScooterPickup,
        'addLuggageCloak': addLuggageCloak,
      };
}

class BookHomestayResponse {
  BookHomestayResponse({
    required this.bookingId,
    required this.totalAmount,
    required this.passToken,
    required this.status,
    required this.suggestedAddOns,
  });

  factory BookHomestayResponse.fromJson(Map<String, dynamic> json) =>
      BookHomestayResponse(
        bookingId: json['bookingId'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        passToken: json['passToken'] as String,
        status: json['status'] as String,
        suggestedAddOns: (json['suggestedAddOns'] as List)
            .map((e) => AddOnSuggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String bookingId;
  final double totalAmount;
  final String passToken;
  final String status;
  final List<AddOnSuggestion> suggestedAddOns;
}

class StaysApi {
  StaysApi(this._api);

  final ApiClient _api;

  Future<List<Homestay>> search({
    required String checkIn,
    required String checkOut,
    int guests = 1,
  }) async {
    final body = await _api.get(
      '/api/homestays/search',
      queryParameters: {
        'checkIn': checkIn,
        'checkOut': checkOut,
        'guests': guests,
      },
    );
    return (body as List)
        .map((e) => Homestay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Homestay> getById(String id) async {
    final body = await _api.get('/api/homestays/$id');
    return Homestay.fromJson(body as Map<String, dynamic>);
  }

  Future<List<Homestay>> list() async {
    final body = await _api.get('/api/homestays');
    return (body as List)
        .map((e) => Homestay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BookHomestayResponse> book(BookHomestayRequest request) async {
    final body = await _api.post(
      '/api/homestays/book',
      data: request.toJson(),
    );
    return BookHomestayResponse.fromJson(body as Map<String, dynamic>);
  }
}

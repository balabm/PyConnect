import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

final p2pEventApiProvider = Provider<P2pEventApi>((ref) {
  return P2pEventApi(ref.read(apiClientProvider));
});

class P2pEventModel {
  P2pEventModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.whatsOffered,
    required this.startsAt,
    required this.endsAt,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.entryPrice,
    required this.capacityLimit,
    required this.ticketsSold,
    required this.status,
    required this.imageUrl,
    required this.isHost,
  });

  factory P2pEventModel.fromJson(Map<String, dynamic> json) => P2pEventModel(
        id: json['id'] as String,
        title: json['title'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        whatsOffered: json['whatsOffered'] as String?,
        startsAt:
            DateTime.tryParse(json['startsAt'] as String? ?? '') ??
            DateTime.now(),
        endsAt:
            DateTime.tryParse(json['endsAt'] as String? ?? '') ??
            DateTime.now(),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        address: json['address'] as String?,
        entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0,
        capacityLimit: json['capacityLimit'] as int? ?? 0,
        ticketsSold: json['ticketsSold'] as int? ?? 0,
        status: json['status'] as String? ?? 'Draft',
        imageUrl: json['imageUrl'] as String?,
        isHost: json['isHost'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? whatsOffered;
  final DateTime startsAt;
  final DateTime endsAt;
  final double latitude;
  final double longitude;
  final String? address;
  final double entryPrice;
  final int capacityLimit;
  final int ticketsSold;
  final String status;
  final String? imageUrl;
  final bool isHost;

  bool get isFree => entryPrice == 0;
  bool get isSoldOut => ticketsSold >= capacityLimit;
  int get spotsLeft => capacityLimit - ticketsSold;
}

class BuyTicketResultModel {
  BuyTicketResultModel({
    required this.ticketId,
    required this.pricePaid,
    required this.razorpayOrderId,
  });

  factory BuyTicketResultModel.fromJson(Map<String, dynamic> json) =>
      BuyTicketResultModel(
        ticketId: json['ticketId'] as String,
        pricePaid: (json['pricePaid'] as num?)?.toDouble() ?? 0,
        razorpayOrderId: json['razorpayOrderId'] as String?,
      );

  final String ticketId;
  final double pricePaid;
  final String? razorpayOrderId;
}

class ConfirmTicketResultModel {
  ConfirmTicketResultModel({required this.passToken});

  factory ConfirmTicketResultModel.fromJson(Map<String, dynamic> json) =>
      ConfirmTicketResultModel(
        passToken: json['passToken'] as String,
      );

  final String passToken;
}

class TicketValidationResponseModel {
  TicketValidationResponseModel({
    required this.isValid,
    required this.buyerName,
    required this.message,
    required this.isDuplicate,
    required this.previousScanAt,
  });

  factory TicketValidationResponseModel.fromJson(Map<String, dynamic> json) =>
      TicketValidationResponseModel(
        isValid: json['isValid'] as bool? ?? false,
        buyerName: json['buyerName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isDuplicate: json['isDuplicate'] as bool? ?? false,
        previousScanAt: json['previousScanAt'] as String?,
      );

  final bool isValid;
  final String buyerName;
  final String message;
  final bool isDuplicate;
  final String? previousScanAt;
}

class AttendeeModel {
  AttendeeModel({
    required this.ticketId,
    required this.buyerName,
    required this.buyerPhone,
    required this.pricePaid,
    required this.status,
    required this.checkedInAt,
    required this.purchasedAt,
  });

  factory AttendeeModel.fromJson(Map<String, dynamic> json) => AttendeeModel(
        ticketId: json['ticketId'] as String,
        buyerName: json['buyerName'] as String? ?? 'Unknown',
        buyerPhone: json['buyerPhone'] as String? ?? '',
        pricePaid: (json['pricePaid'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Active',
        checkedInAt: json['checkedInAt'] as String?,
        purchasedAt:
            DateTime.tryParse(json['purchasedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  final String ticketId;
  final String buyerName;
  final String buyerPhone;
  final double pricePaid;
  final String status;
  final String? checkedInAt;
  final DateTime purchasedAt;
}

class P2pEventApi {
  P2pEventApi(this._api);

  final ApiClient _api;

  Future<P2pEventModel> createEvent({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    required double latitude,
    required double longitude,
    double entryPrice = 0,
    int capacityLimit = 50,
    String? description,
    String? whatsOffered,
    String? address,
    String? imageUrl,
  }) async {
    final body = await _api.post('/api/p2p-events', data: {
      'title': title,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'entryPrice': entryPrice,
      'capacityLimit': capacityLimit,
      'description': description,
      'whatsOffered': whatsOffered,
      'address': address,
      'imageUrl': imageUrl,
    });
    return P2pEventModel.fromJson(body as Map<String, dynamic>);
  }

  Future<void> publishEvent(String eventId) async {
    await _api.post('/api/p2p-events/$eventId/publish');
  }

  Future<void> cancelEvent(String eventId) async {
    await _api.post('/api/p2p-events/$eventId/cancel');
  }

  Future<List<P2pEventModel>> browseEvents() async {
    final body = await _api.get('/api/p2p-events');
    final list = body as List? ?? [];
    return list
        .map((e) => P2pEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<P2pEventModel> getBySlug(String slug) async {
    final body = await _api.get('/api/p2p-events/$slug');
    return P2pEventModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<P2pEventModel>> myEvents() async {
    final body = await _api.get('/api/p2p-events/my-events');
    final list = body as List? ?? [];
    return list
        .map((e) => P2pEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BuyTicketResultModel> buyTicket(String eventId) async {
    final body = await _api.post('/api/p2p-events/$eventId/tickets');
    return BuyTicketResultModel.fromJson(body as Map<String, dynamic>);
  }

  Future<ConfirmTicketResultModel> confirmTicket({
    required String ticketId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    final body =
        await _api.post('/api/p2p-events/tickets/$ticketId/confirm', data: {
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'signature': signature,
    });
    return ConfirmTicketResultModel.fromJson(body as Map<String, dynamic>);
  }

  Future<TicketValidationResponseModel> validateTicket({
    required String eventId,
    required String qrPayload,
  }) async {
    final body =
        await _api.post('/api/p2p-events/$eventId/validate-ticket', data: {
      'qrPayload': qrPayload,
    });
    return TicketValidationResponseModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<AttendeeModel>> getAttendees(String eventId) async {
    final body = await _api.get('/api/p2p-events/$eventId/attendees');
    final list = body as List? ?? [];
    return list
        .map((e) => AttendeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

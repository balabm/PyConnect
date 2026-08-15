import '../../../core/network/api_client.dart';

class SupportTicketModel {
  SupportTicketModel({
    required this.id,
    required this.status,
    required this.priority,
    required this.source,
    this.issueCategory,
    required this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) =>
      SupportTicketModel(
        id: json['id'] as String,
        status: json['status'] as String,
        priority: json['priority'] as String,
        source: json['source'] as String,
        issueCategory: json['issueCategory'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String status;
  final String priority;
  final String source;
  final String? issueCategory;
  final DateTime createdAt;
}

class TicketMessageModel {
  TicketMessageModel({
    required this.id,
    required this.senderRole,
    required this.messageText,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) =>
      TicketMessageModel(
        id: json['id'] as String,
        senderRole: json['senderRole'] as String,
        messageText: json['messageText'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String senderRole;
  final String messageText;
  final DateTime createdAt;
}

class MessageResponse {
  MessageResponse({
    required this.ticketId,
    required this.aiReply,
    required this.isCritical,
    required this.priority,
    required this.detectedIntent,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(
        ticketId: json['ticketId'] as String,
        aiReply: json['aiReply'] as String,
        isCritical: json['isCritical'] as bool,
        priority: json['priority'] as String,
        detectedIntent: json['detectedIntent'] as String,
      );

  final String ticketId;
  final String aiReply;
  final bool isCritical;
  final String priority;
  final String detectedIntent;
}

class CriticalTicketModel {
  CriticalTicketModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.issueCategory,
    this.latitude,
    this.longitude,
    required this.priority,
    required this.source,
    required this.createdAt,
  });

  factory CriticalTicketModel.fromJson(Map<String, dynamic> json) =>
      CriticalTicketModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        issueCategory: json['issueCategory'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        priority: json['priority'] as String,
        source: json['source'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String userId;
  final String userName;
  final String? issueCategory;
  final double? latitude;
  final double? longitude;
  final String priority;
  final String source;
  final DateTime createdAt;
}

class SosRequest {
  SosRequest({
    required this.issue,
    this.latitude,
    this.longitude,
  });

  final String issue;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> toJson() => {
        'issue': issue,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}

class SupportApi {
  SupportApi(this._api);

  final ApiClient _api;

  Future<MessageResponse> sendMessage(String messageText) async {
    final body = await _api.post(
      '/api/support/message',
      data: {'messageText': messageText},
    );
    return MessageResponse.fromJson(body as Map<String, dynamic>);
  }

  Future<CriticalTicketModel> createSos(SosRequest request) async {
    final body = await _api.post(
      '/api/support/sos',
      data: request.toJson(),
    );
    return CriticalTicketModel.fromJson(body as Map<String, dynamic>);
  }

  Future<List<SupportTicketModel>> getTickets() async {
    final body = await _api.get('/api/support/tickets');
    return (body as List)
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TicketMessageModel>> getTicketMessages(String ticketId) async {
    final body = await _api.get('/api/support/tickets/$ticketId/messages');
    return (body as List)
        .map((e) => TicketMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

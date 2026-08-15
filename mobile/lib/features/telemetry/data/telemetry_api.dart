import '../../../core/network/api_client.dart';

class TelemetryApi {
  TelemetryApi(this._client);

  final ApiClient _client;

  Future<void> logEvents(List<Map<String, dynamic>> events, {String? sessionId}) async {
    await _client.post('/api/telemetry/log', data: {
      'sessionId': sessionId,
      'events': events,
    });
  }
}

import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../config/app_config.dart';

/// Wrapper around the SignalR .NET Core client for managing hub connections.
/// Handles auth token injection, auto-reconnect, and event subscription.
class SignalRClient {
  SignalRClient({required this.hubPath, required this.tokenProvider});

  final String hubPath;
  final String? Function()? tokenProvider;

  HubConnection? _connection;
  final Map<String, List<void Function(List<Object?>?)>> _handlers = {};
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;

  /// Exponential backoff delays (in seconds) for manual reconnection in the
  /// `onclose` handler. Capped at 60s with 8 retries. Reset to zero on a
  /// successful reconnect. The longer delays (45s, 60s) accommodate
  /// intermittent TLS reset recovery on the deployed backend.
  static const List<int> _backoffDelays = [2, 5, 10, 20, 30, 45, 60, 60];

  /// Callback invoked when the reconnection state changes. Receives `true`
  /// when the connection is lost and a reconnect is in progress, `false`
  /// when the connection has been restored. The driver shell can listen to
  /// this to show/hide a "Reconnecting…" banner.
  void Function(bool isReconnecting)? onConnectionStateChanged;

  final List<StreamController<List<Object?>>> _controllers = [];

  bool get isConnected => _connection?.state == HubConnectionState.Connected;
  bool get isReconnecting => _isReconnecting;

  String get _hubUrl {
    final base = AppConfig.apiBaseUrl;
    return '$base$hubPath';
  }

  /// Connect to the hub. Idempotent — safe to call multiple times.
  Future<void> connect() async {
    if (_isConnecting || isConnected) return;
    _isConnecting = true;
    _shouldReconnect = true;

    try {
      _connection = HubConnectionBuilder()
          .withUrl(_hubUrl, options: HttpConnectionOptions(
            accessTokenFactory: () async {
              final token = tokenProvider?.call();
              return token ?? '';
            },
          ))
          .withAutomaticReconnect()
          .build();

      _connection!.onreconnecting(({error}) {
        // Connection lost, attempting to reconnect
        _isReconnecting = true;
        onConnectionStateChanged?.call(true);
      });

      _connection!.onreconnected(({connectionId}) {
        // Reconnected — handlers are automatically preserved.
        // Reset the manual reconnect attempt counter on success.
        _reconnectAttempts = 0;
        _isReconnecting = false;
        onConnectionStateChanged?.call(false);
      });

      _connection!.onclose(({error}) {
        // Detect auth rejection (401/403). For auth errors, stop retrying
        // and signal permanent disconnection so the driver shell can toggle
        // offline and prompt re-authentication. For transient network errors
        // (SocketException, timeout), retry with exponential backoff.
        final errorText = error?.toString().toLowerCase() ?? '';
        final isAuthError = errorText.contains('401') ||
            errorText.contains('403') ||
            errorText.contains('unauthorized');

        if (_shouldReconnect && !isAuthError) {
          // Exponential backoff: 3s, 6s, 12s, 24s, 30s (capped).
          final delayIndex = _reconnectAttempts < _backoffDelays.length
              ? _reconnectAttempts
              : _backoffDelays.length - 1;
          final delaySeconds = _backoffDelays[delayIndex];
          _reconnectAttempts++;
          _isReconnecting = true;
          onConnectionStateChanged?.call(true);
          Future.delayed(Duration(seconds: delaySeconds), () {
            if (_shouldReconnect) connect();
          });
        } else {
          // Intentional disconnect or auth rejection — stop retrying.
          _shouldReconnect = false;
          _isReconnecting = false;
          _reconnectAttempts = 0;
          onConnectionStateChanged?.call(false);
        }
      });

      // Register all pending handlers before starting
      for (final entry in _handlers.entries) {
        for (final callback in entry.value) {
          _connection!.on(entry.key, callback);
        }
      }

      await _connection!.start();
      // Connection established — reset the manual reconnect attempt counter.
      _reconnectAttempts = 0;
    } finally {
      _isConnecting = false;
    }
  }

  /// Subscribe to a server event. Returns a stream of events.
  Stream<List<Object?>> on(String eventName) {
    final controller = StreamController<List<Object?>>.broadcast();
    void callback(List<Object?>? args) {
      if (!controller.isClosed) controller.add(args ?? []);
    }

    _handlers.putIfAbsent(eventName, () => []).add(callback);

    if (_connection != null) {
      _connection!.on(eventName, callback);
    }

    _controllers.add(controller);
    return controller.stream;
  }

  /// Invoke a server method.
  Future<void> invoke(String methodName, [List<Object?>? args]) async {
    if (_connection == null || !isConnected) {
      await connect();
    }
    await _connection?.invoke(methodName, args: args?.cast<Object>());
  }

  /// Disconnect from the hub.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    for (final c in _controllers) {
      await c.close();
    }
    _controllers.clear();
    _handlers.clear();
    await _connection?.stop();
    _connection = null;
  }
}

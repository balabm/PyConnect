import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A queued API mutation that needs to be replayed when network is restored.
///
/// Stores the HTTP method, path, and optional body so the request can be
/// retried exactly once. The [id] is a UUID for deduplication.
@immutable
class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
  });

  final String id;
  final String method; // 'POST', 'PUT', 'DELETE'
  final String path;
  final Map<String, dynamic>? body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        if (body != null) 'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedMutation.fromJson(Map<String, dynamic> json) => QueuedMutation(
        id: json['id'] as String,
        method: json['method'] as String,
        path: json['path'] as String,
        body: json['body'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// An offline mutation queue for the Captain (driver) app.
///
/// When a driver taps "Complete Trip" or "Arrived" and the network is down
/// (DioException with type connectionError/connectionTimeout), the mutation
/// is saved to a persistent SharedPreferences-backed queue. The UI updates
/// optimistically so the driver is not blocked. When network is restored
/// (detected on the next successful API call or periodic check), the queue
/// is flushed to the backend in order.
///
/// This is intentionally lightweight — no Hive or SQLite dependency. The
/// queue is small (rarely more than 1-2 items) and persisted as JSON in
/// SharedPreferences.
class OfflineMutationQueue {
  static const _storageKey = 'offline_mutation_queue';

  final SharedPreferences _prefs;
  final Future<bool> Function(QueuedMutation) _sender;
  final VoidCallback? onQueueDrained;

  final _controller = StreamController<List<QueuedMutation>>.broadcast();
  Stream<List<QueuedMutation>> get queueStream => _controller.stream;

  List<QueuedMutation> _queue = [];
  bool _flushing = false;

  OfflineMutationQueue(this._prefs, this._sender, {this.onQueueDrained}) {
    _loadQueue();
  }

  /// Loads the persisted queue from SharedPreferences on startup.
  void _loadQueue() {
    try {
      final json = _prefs.getString(_storageKey);
      if (json != null && json.isNotEmpty) {
        final list = jsonDecode(json) as List;
        _queue = list
            .map((e) => QueuedMutation.fromJson(e as Map<String, dynamic>))
            .toList();
        _controller.add(_queue);
      }
    } catch (_) {
      // Corrupted queue — start fresh.
      _queue = [];
    }
  }

  /// Persists the current queue to SharedPreferences.
  Future<void> _persist() async {
    try {
      final json = jsonEncode(_queue.map((m) => m.toJson()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (_) {
      // Storage write failed — the queue is still in memory.
    }
    _controller.add(_queue);
  }

  /// The current queue (read-only view).
  List<QueuedMutation> get queue => List.unmodifiable(_queue);

  /// Whether the queue has any pending mutations.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Enqueues a mutation. Called when a network error occurs during an API
  /// call. The mutation will be replayed when [flush] is called.
  Future<void> enqueue(QueuedMutation mutation) async {
    // Deduplicate: don't enqueue the same path+method twice.
    final exists = _queue.any((m) => m.path == mutation.path && m.method == mutation.method);
    if (exists) return;

    _queue.add(mutation);
    await _persist();
  }

  /// Attempts to flush all queued mutations to the backend. Called when
  /// network connectivity is restored. Mutations are sent in order. If any
  /// mutation fails, the flush stops and the remaining items stay queued.
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;

    try {
      while (_queue.isNotEmpty) {
        final mutation = _queue.first;
        try {
          final success = await _sender(mutation);
          if (success) {
            _queue.removeAt(0);
            await _persist();
          } else {
            // Sender returned false — stop flushing, try again later.
            break;
          }
        } on DioException catch (e) {
          // Still no network — stop flushing.
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            break;
          }
          // Non-network error — the mutation itself is bad. Drop it so it
          // doesn't block the rest of the queue.
          _queue.removeAt(0);
          await _persist();
        } catch (_) {
          // Unknown error — drop the mutation and continue.
          _queue.removeAt(0);
          await _persist();
        }
      }

      if (_queue.isEmpty) {
        onQueueDrained?.call();
      }
    } finally {
      _flushing = false;
    }
  }

  /// Clears all queued mutations without sending them. Used on sign-out.
  Future<void> clear() async {
    _queue.clear();
    await _prefs.remove(_storageKey);
    _controller.add(_queue);
  }

  void dispose() {
    _controller.close();
  }
}

/// Checks if a DioException is a network error (vs a server error).
/// Network errors are queued for retry; server errors are surfaced to the
/// user immediately.
bool isNetworkError(DioException e) {
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;
}

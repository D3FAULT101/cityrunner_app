import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';

/// Wraps a single WebSocket connection to the City Runner backend with
/// automatic reconnection (with backoff) and JSON message decoding.
///
/// Used for the public bus feed, the driver channel, the admin channel, and
/// a passenger's booking-status channel. One instance per channel; call
/// [connect] to (re)start it and [dispose] when the screen/session ends.
class RealtimeChannel {
  RealtimeChannel({
    required this.path,
    required this.onMessage,
    this.onConnected,
    this.onDisconnected,
  });

  /// Path relative to the API base, e.g. '/ws/public' or '/ws/driver?token=...'.
  final String path;
  final void Function(Map<String, dynamic> message) onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _retryCount = 0;

  bool get isConnected => _channel != null;

  void connect() {
    if (_disposed) return;
    _teardownSocket();

    final Uri uri;
    try {
      uri = _buildUri();
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        (event) {
          _retryCount = 0;
          onConnected?.call();
          _handleRaw(event);
        },
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardownSocket();
  }

  Uri _buildUri() {
    final base = AppConstants.apiBaseUrl;
    final httpUri = Uri.parse(base);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final wsBase = httpUri.replace(scheme: scheme);
    return Uri.parse('$wsBase$path');
  }

  void _handleRaw(dynamic event) {
    if (event is! String) return;
    try {
      final decoded = jsonDecode(event);
      if (decoded is Map<String, dynamic>) {
        onMessage(decoded);
      }
    } catch (_) {
      // Ignore malformed frames rather than crashing the listener.
    }
  }

  void _handleDisconnect() {
    _teardownSocket();
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _teardownSocket() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _retryCount = (_retryCount + 1).clamp(0, 5);
    final delaySeconds = [1, 2, 4, 8, 15, 20][_retryCount];
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), connect);
  }
}

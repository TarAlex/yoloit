import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../generated/mindmap_sync.pb.dart';

/// WebSocket server that runs on the host machine.
/// Broadcasts [SyncEnvelope] proto messages to all connected clients and
/// forwards client delta events to the host's BLoC via [onClientEvent].
class CollaborationServer {
  CollaborationServer({required this.onClientEvent, this.port = 40401});

  final void Function(SyncEnvelope env) onClientEvent;
  final int port;

  HttpServer? _httpServer;
  final Map<String, WebSocketChannel> _clients = {};

  bool get isRunning => _httpServer != null;
  int  get clientCount => _clients.length;

  /// Starts the WebSocket server. Returns the local IP:port string.
  Future<String> start() async {
    final handler = webSocketHandler(_handleConnection);
    _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    final ip = await _localIp();
    return '$ip:$port';
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
    _clients.clear();
  }

  /// Sends a full state snapshot to all connected clients.
  void broadcastSnapshot(SyncEnvelope envelope) => _broadcast(envelope);

  /// Sends a delta event to all connected clients (except optionally [exclude]).
  void broadcastDelta(SyncEnvelope envelope, {String? exclude}) {
    for (final entry in _clients.entries) {
      if (entry.key == exclude) continue;
      _sendTo(entry.value, envelope);
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _handleConnection(WebSocketChannel channel) {
    final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
    _clients[clientId] = channel;

    channel.stream.listen(
      (data) {
        try {
          final bytes = data is List<int> ? data : (data as dynamic).cast<int>();
          final env   = SyncEnvelope.fromBuffer(bytes);
          // Forward client events to the host BLoC.
          onClientEvent(env);
          // Re-broadcast delta to other clients (exclude sender).
          if (env.hasDelta()) {
            broadcastDelta(env, exclude: clientId);
          }
        } catch (e) {
          // Malformed message — ignore.
        }
      },
      onDone: () {
        _clients.remove(clientId);
        _broadcast(SyncEnvelope(
          senderId: 'server',
          disconnected: ClientDisconnected(clientId: clientId),
        ));
      },
      onError: (_) => _clients.remove(clientId),
    );

    // Notify others that a new client joined.
    _broadcast(SyncEnvelope(
      senderId: 'server',
      connected: ClientConnected(clientId: clientId, clientName: 'Remote'),
    ));
  }

  void _broadcast(SyncEnvelope envelope) {
    for (final ch in _clients.values) {
      _sendTo(ch, envelope);
    }
  }

  void _sendTo(WebSocketChannel ch, SyncEnvelope envelope) {
    try {
      ch.sink.add(envelope.writeToBuffer());
    } catch (_) {}
  }

  static Future<String> _localIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return '127.0.0.1';
  }
}

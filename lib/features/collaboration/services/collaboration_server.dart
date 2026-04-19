import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/sync_message.dart';

/// WebSocket server that runs on the host machine.
/// Uses JSON text frames — no protobuf codegen required.
class CollaborationServer {
  CollaborationServer({required this.onClientMessage, this.port = 40401});

  final void Function(String clientId, SyncMessage msg) onClientMessage;
  final int port;

  HttpServer? _httpServer;
  final Map<String, WebSocketChannel> _clients = {};

  bool get isRunning  => _httpServer != null;
  int  get clientCount => _clients.length;

  Future<String> start() async {
    final handler = webSocketHandler(_handleConnection);
    _httpServer   = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    return '${await _localIp()}:$port';
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
    _clients.clear();
  }

  void broadcastRaw(SyncMessage msg, {String? exclude}) {
    final encoded = msg.encode();
    for (final entry in _clients.entries) {
      if (entry.key == exclude) continue;
      try { entry.value.sink.add(encoded); } catch (_) {}
    }
  }

  void sendTo(String clientId, SyncMessage msg) {
    try { _clients[clientId]?.sink.add(msg.encode()); } catch (_) {}
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _handleConnection(WebSocketChannel channel) {
    final clientId = 'c_${DateTime.now().millisecondsSinceEpoch}';
    _clients[clientId] = channel;

    channel.stream.listen(
      (raw) {
        final msg = SyncMessage.decode(raw);
        if (msg == null) return;
        onClientMessage(clientId, msg);
        // Re-broadcast deltas to other clients.
        if (msg.type.startsWith('delta.')) {
          broadcastRaw(msg, exclude: clientId);
        }
      },
      onDone:  () => _onDisconnect(clientId),
      onError: (_) => _onDisconnect(clientId),
      cancelOnError: true,
    );

    // Notify all clients (including new one) that someone joined.
    broadcastRaw(SyncMessage.connected(clientId, 'Remote'));
  }

  void _onDisconnect(String clientId) {
    _clients.remove(clientId);
    broadcastRaw(SyncMessage.disconnected(clientId));
  }

  static Future<String> _localIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4, includeLoopback: false);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return '127.0.0.1';
  }
}

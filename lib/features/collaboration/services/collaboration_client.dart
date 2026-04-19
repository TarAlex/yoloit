import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/sync_message.dart';

/// WebSocket client for the guest machine.
/// Sends JSON text frames and receives [SyncMessage] callbacks.
class CollaborationClient {
  CollaborationClient({required this.onMessage});

  final void Function(SyncMessage msg) onMessage;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;

  bool get isConnected => _channel != null;

  Future<void> connect(String host, int port) async {
    final uri = Uri.parse('ws://$host:$port');
    _channel  = WebSocketChannel.connect(uri);
    await _channel!.ready; // throws if unreachable

    _sub = _channel!.stream.listen(
      (raw) {
        final msg = SyncMessage.decode(raw);
        if (msg != null) onMessage(msg);
      },
      onDone: () {
        if (!_disposed) onMessage(SyncMessage.disconnected('server'));
        _channel = null;
      },
      onError: (_) => _channel = null,
      cancelOnError: true,
    );

    // Handshake
    _send(SyncMessage.hello(
      clientId:   'guest_${DateTime.now().millisecondsSinceEpoch}',
      clientName: 'Remote Guest',
    ));
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  void sendMessage(SyncMessage msg) => _send(msg);

  void _send(SyncMessage msg) {
    try { _channel?.sink.add(msg.encode()); } catch (_) {}
  }
}

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../generated/mindmap_sync.pb.dart';

/// WebSocket client that runs on the guest machine.
/// Connects to a host's [CollaborationServer] and receives [SyncEnvelope]
/// messages. The host's state is applied to the guest's BLoC via [onEnvelope].
class CollaborationClient {
  CollaborationClient({required this.onEnvelope});

  final void Function(SyncEnvelope env) onEnvelope;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;

  bool get isConnected => _channel != null;

  /// Connects to ws://[host]:[port] and returns when the WS handshake is done.
  /// Throws on connection failure.
  Future<void> connect(String host, int port) async {
    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready; // throws if unreachable

    _sub = _channel!.stream.listen(
      (data) {
        try {
          final bytes = data is List<int> ? data : (data as dynamic).cast<int>();
          final env   = SyncEnvelope.fromBuffer(bytes);
          onEnvelope(env);
        } catch (_) {}
      },
      onDone: () {
        if (!_disposed) onEnvelope(SyncEnvelope(
          senderId: 'server',
          disconnected: ClientDisconnected(clientId: 'server'),
        ));
        _channel = null;
      },
      onError: (_) => _channel = null,
      cancelOnError: true,
    );

    // Send hello handshake.
    _send(SyncEnvelope(
      senderId: 'guest',
      hello: ClientHello(
        clientId:   'guest_${DateTime.now().millisecondsSinceEpoch}',
        clientName: 'Remote Guest',
        version:    '1.0',
      ),
    ));
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  /// Sends a delta event to the host (e.g., node drag from the guest).
  void sendDelta(DeltaEvent delta) {
    _send(SyncEnvelope(senderId: 'guest', delta: delta));
  }

  void _send(SyncEnvelope env) {
    try {
      _channel?.sink.add(env.writeToBuffer());
    } catch (_) {}
  }
}

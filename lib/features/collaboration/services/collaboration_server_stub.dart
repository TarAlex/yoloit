import '../model/sync_message.dart';

/// Web stub — the browser cannot host a WebSocket server.
class CollaborationServer {
  CollaborationServer({
    required void Function(String, SyncMessage) onClientMessage,
    this.port = 40401,
  });

  final int port;
  int get clientCount => 0;
  String get webClientUrl => '';
  Future<String> start() async => throw UnsupportedError(
      'Hosting is not available in browser mode.');

  Future<void> stop() async {}

  void broadcastRaw(SyncMessage msg) {}
  void sendTo(String clientId, SyncMessage msg) {}
}

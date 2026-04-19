import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../model/sync_message.dart';

/// WebSocket server (port [port]) + static HTTP server (port [httpPort]).
/// The HTTP server serves the Flutter web build from [webClientPath] so any
/// browser on the local network can open the Space guest UI.
class CollaborationServer {
  CollaborationServer({
    required this.onClientMessage,
    this.port = 40401,
    this.httpPort = 40400,
  });

  final void Function(String clientId, SyncMessage msg) onClientMessage;
  final int port;
  final int httpPort;

  HttpServer? _httpServer;
  HttpServer? _staticServer;
  final Map<String, WebSocketChannel> _clients = {};

  bool get isRunning   => _httpServer != null;
  int  get clientCount => _clients.length;

  /// Returns the address string "ip:port" of the WS server.
  /// Also starts the static HTTP server if a web-client directory exists.
  Future<String> start() async {
    final handler = webSocketHandler(_handleConnection);
    _httpServer   = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

    // Start static HTTP server for the browser guest UI (if web build exists).
    await _startStaticServer();

    return '${await _localIp()}:$port';
  }

  /// The URL that guests should open in their browser.
  String get webClientUrl {
    if (_staticServer == null) return '';
    return 'http://${_staticServer!.address.address}:$httpPort';
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    await _staticServer?.close(force: true);
    _httpServer   = null;
    _staticServer = null;
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

  /// Tries to start a static file server for the Flutter web build.
  /// Looks in known locations: next to the executable, build/web, ~/.yoloit/web_client.
  Future<void> _startStaticServer() async {
    final webDir = await _findWebClientDir();
    if (webDir == null) return;
    try {
      final staticHandler = createStaticHandler(
        webDir,
        defaultDocument: 'index.html',
        serveFilesOutsidePath: false,
      );
      _staticServer = await shelf_io.serve(
          staticHandler, InternetAddress.anyIPv4, httpPort);
    } catch (_) {
      // Static server is optional — don't fail hosting if it can't start.
    }
  }

  /// Candidate directories where the Flutter web build might live.
  static Future<String?> _findWebClientDir() async {
    final exe = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;

    final candidates = [
      // macOS app bundle: YoLoIT.app/Contents/MacOS/../Resources/web_client
      '$appDir/../Resources/web_client',
      // Sibling to executable (Linux / Windows portable)
      '$appDir/web_client',
      // Development build output
      '${Directory.current.path}/build/web',
      // User cache
      '${Platform.environment['HOME']}/.yoloit/web_client',
    ];

    for (final path in candidates) {
      final dir = Directory(path);
      if (await dir.exists() &&
          await File('$path/index.html').exists()) {
        return dir.resolveSymbolicLinksSync();
      }
    }
    return null;
  }

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

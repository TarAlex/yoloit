import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import '../model/sync_message.dart';

/// WebSocket server (port [port]) + static HTTP server (port [httpPort]).
/// Uses dart:io WebSocket directly — more reliable for cross-machine LAN connections.
class CollaborationServer {
  CollaborationServer({
    required this.onClientMessage,
    this.port = 40401,
    this.httpPort = 40400,
  });

  final void Function(String clientId, SyncMessage msg) onClientMessage;
  final int port;
  final int httpPort;

  HttpServer? _wsServer;
  HttpServer? _staticServer;
  final Map<String, WebSocket> _clients = {};
  String _resolvedIp = '127.0.0.1';

  bool get isRunning   => _wsServer != null;
  int  get clientCount => _clients.length;

  /// Returns the address string "ip:port" of the WS server.
  /// Also starts the static HTTP server if a web-client directory exists.
  Future<String> start() async {
    _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _wsServer!.listen(_handleRequest);
    _resolvedIp = await _localIp();

    await _startStaticServer();
    return '$_resolvedIp:$port';
  }

  /// The URL that guests should open in their browser.
  String get webClientUrl {
    if (_staticServer == null) return '';
    return 'http://$_resolvedIp:$httpPort';
  }

  Future<void> stop() async {
    for (final ws in _clients.values) {
      try { await ws.close(); } catch (_) {}
    }
    _clients.clear();
    await _wsServer?.close(force: true);
    await _staticServer?.close(force: true);
    _wsServer   = null;
    _staticServer = null;
  }

  void broadcastRaw(SyncMessage msg, {String? exclude}) {
    final encoded = msg.encode();
    for (final entry in _clients.entries) {
      if (entry.key == exclude) continue;
      try { entry.value.add(encoded); } catch (_) {}
    }
  }

  void sendTo(String clientId, SyncMessage msg) {
    try { _clients[clientId]?.add(msg.encode()); } catch (_) {}
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      // Return 200 for health-checks from the static server / browser preflight
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write('YoLoIT collaboration server')
        ..close();
      return;
    }
    try {
      final ws        = await WebSocketTransformer.upgrade(request);
      final clientId  = 'c_${DateTime.now().millisecondsSinceEpoch}';
      _clients[clientId] = ws;

      ws.listen(
        (raw) {
          final msg = SyncMessage.decode(raw);
          if (msg == null) return;
          onClientMessage(clientId, msg);
          if (msg.type.startsWith('delta.')) {
            broadcastRaw(msg, exclude: clientId);
          }
        },
        onDone:    () => _onDisconnect(clientId),
        onError:   (_) => _onDisconnect(clientId),
        cancelOnError: true,
      );

      broadcastRaw(SyncMessage.connected(clientId, 'Remote'));
    } catch (e) {
      // ignore failed upgrade
    }
  }

  void _onDisconnect(String clientId) {
    _clients.remove(clientId);
    broadcastRaw(SyncMessage.disconnected(clientId));
  }

  /// Tries to start a static file server for the Flutter web build.
  Future<void> _startStaticServer() async {
    final webDir = await _findWebClientDir();
    if (webDir == null) return;
    try {
      final staticHandler = createStaticHandler(
        webDir,
        defaultDocument: 'index.html',
        serveFilesOutsidePath: false,
      );
      // Wrap with CORS headers so the browser can load the JS from the same server.
      final corsHandler = shelf.Pipeline()
          .addMiddleware(_corsMiddleware())
          .addHandler(staticHandler);
      _staticServer = await shelf_io.serve(
          corsHandler, InternetAddress.anyIPv4, httpPort);
    } catch (_) {
      // Static server is optional.
    }
  }

  static shelf.Middleware _corsMiddleware() {
    return (handler) => (request) async {
          final resp = await handler(request);
          return resp.change(headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            ...resp.headers,
          });
        };
  }

  /// Candidate directories where the Flutter web build might live.
  static Future<String?> _findWebClientDir() async {
    final exe    = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;

    final candidates = [
      '$appDir/../Resources/web_client',
      '$appDir/web_client',
      '${Directory.current.path}/build/web',
      '${Platform.environment['HOME']}/.yoloit/web_client',
    ];

    for (final path in candidates) {
      final dir = Directory(path);
      if (await dir.exists() && await File('$path/index.html').exists()) {
        return dir.resolveSymbolicLinksSync();
      }
    }
    return null;
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


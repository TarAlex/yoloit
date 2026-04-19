import 'dart:async';
import 'dart:io';

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
    // Wrap async handler so unhandled Future errors don't crash the isolate.
    _wsServer!.listen(
      (req) => _handleRequest(req).catchError((_) {}),
      onError: (_) {},
    );
    _resolvedIp = await _localIp();

    // Auto-install web client to ~/.yoloit/web_client if not present yet.
    await _ensureWebClientInstalled();

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
      // Health-check / browser preflight
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write('YoLoIT collaboration server');
      await request.response.close();
      return;
    }
    try {
      final ws       = await WebSocketTransformer.upgrade(request);
      final clientId = 'c_${DateTime.now().millisecondsSinceEpoch}';
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
        onDone:        () => _onDisconnect(clientId),
        onError:       (_) => _onDisconnect(clientId),
        cancelOnError: true,
      );

      // Send full state snapshot to the new client.
      broadcastRaw(SyncMessage.connected(clientId, 'Remote'));
    } catch (_) {
      // ignore failed upgrade (e.g. client sent non-WS request to WS port)
    }
  }

  void _onDisconnect(String clientId) {
    _clients.remove(clientId);
    broadcastRaw(SyncMessage.disconnected(clientId));
  }

  // ── Static HTTP server (pure dart:io, no shelf) ──────────────────────────

  /// Starts a minimal HTTP file server on [httpPort] for the Flutter web build.
  Future<void> _startStaticServer() async {
    final webDir = await _findWebClientDir();
    if (webDir == null) return;
    try {
      _staticServer = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
      _staticServer!.listen(
        (req) => _serveFile(req, webDir).catchError((_) {}),
        onError: (_) {},
      );
    } catch (_) {
      _staticServer = null; // Optional — don't fail hosting.
    }
  }

  /// Serves a single file request from [webDir] with CORS headers.
  static Future<void> _serveFile(HttpRequest req, String webDir) async {
    // OPTIONS preflight
    if (req.method == 'OPTIONS') {
      req.response
        ..statusCode = HttpStatus.noContent
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS')
        ..headers.set('Access-Control-Allow-Headers', 'Content-Type');
      await req.response.close();
      return;
    }

    var urlPath = req.uri.path;
    // SPA routing: serve index.html for all non-file paths.
    if (urlPath == '/' || urlPath.isEmpty || !urlPath.contains('.')) {
      urlPath = '/index.html';
    }
    // Sanitise: strip query, collapse "..", disallow escaping webDir.
    final safePath = Uri.decodeFull(urlPath.split('?').first)
        .replaceAll(RegExp(r'\.\.[\\/]'), '');
    final filePath = '$webDir$safePath';
    final file = File(filePath);

    req.response.headers.set('Access-Control-Allow-Origin', '*');
    req.response.headers.set('Cache-Control', 'no-cache');

    if (await file.exists()) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = _mimeType(safePath);
      await req.response.addStream(file.openRead());
    } else {
      // SPA fallback — serve index.html so Flutter router takes over.
      final index = File('$webDir/index.html');
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html;
      await req.response.addStream(index.openRead());
    }
    await req.response.close();
  }

  static ContentType _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'html' => ContentType.html,
      'js'   => ContentType('application', 'javascript', charset: 'utf-8'),
      'css'  => ContentType('text', 'css', charset: 'utf-8'),
      'json' => ContentType.json,
      'png'  => ContentType('image', 'png'),
      'ico'  => ContentType('image', 'x-icon'),
      'svg'  => ContentType('image', 'svg+xml'),
      'wasm' => ContentType('application', 'wasm'),
      _      => ContentType.binary,
    };
  }

  /// Auto-copies the web client from build/web to ~/.yoloit/web_client if needed.
  static Future<void> _ensureWebClientInstalled() async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final dest = '$home/.yoloit/web_client';
    if (await File('$dest/index.html').exists()) return; // already installed

    // Search for build/web relative to executable — go up the dir tree.
    final exe = Platform.resolvedExecutable;
    var dir = File(exe).parent;
    for (int i = 0; i < 12; i++) {
      final candidate = '${dir.path}/build/web';
      if (await File('$candidate/index.html').exists()) {
        try {
          await Directory(dest).create(recursive: true);
          await _copyDirectory(Directory(candidate), Directory(dest));
        } catch (_) {}
        return;
      }
      dir = dir.parent;
    }
  }

  static Future<void> _copyDirectory(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final target = '${dest.path}/${entity.uri.pathSegments.last}';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(target));
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  /// Candidate directories where the Flutter web build might live.
  static Future<String?> _findWebClientDir() async {
    final home   = Platform.environment['HOME'] ?? '';
    final exe    = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;

    // Fixed-priority candidates.
    final fixed = [
      '$appDir/../Resources/web_client',  // macOS app bundle Resources
      '$appDir/web_client',               // sibling to executable
      '$home/.yoloit/web_client',         // user install / auto-copy
      '${Directory.current.path}/build/web', // flutter run dev
    ];
    for (final path in fixed) {
      if (await File('$path/index.html').exists()) return _resolved(path);
    }

    // Traverse up from executable to find project build/web.
    var dir = File(exe).parent;
    for (int i = 0; i < 12; i++) {
      final path = '${dir.path}/build/web';
      if (await File('$path/index.html').exists()) return _resolved(path);
      dir = dir.parent;
    }
    return null;
  }

  static String _resolved(String path) =>
      Directory(path).resolveSymbolicLinksSync();

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


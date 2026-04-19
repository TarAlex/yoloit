import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../model/sync_message.dart';

/// WebSocket server (port [port]) + static HTTP server (port [httpPort]).
///
/// Uses raw [ServerSocket] — NOT [HttpServer] — to avoid a macOS/dart bug
/// where dart:_http calls setOption(TCP_NODELAY) on accepted sockets and
/// gets errno=22 (EINVAL) for connections coming in on the LAN interface.
/// Both the WS upgrade and HTTP file serving are implemented manually.
class CollaborationServer {
  CollaborationServer({
    required this.onClientMessage,
    this.port = 40401,
    this.httpPort = 40400,
  });

  final void Function(String clientId, SyncMessage msg) onClientMessage;
  final int port;
  final int httpPort;

  ServerSocket? _wsServerSocket;
  ServerSocket? _staticServerSocket;
  final Map<String, WebSocket> _clients = {};
  String _resolvedIp = '127.0.0.1';

  bool get isRunning   => _wsServerSocket != null;
  int  get clientCount => _clients.length;

  /// Returns the address string "ip:port" of the WS server.
  Future<String> start() async {
    _wsServerSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _wsServerSocket!.listen(
      (s) => _handleWsSocket(s).catchError((_) { _destroySocket(s); }),
      onError: (_) {},
    );
    _resolvedIp = await _localIp();
    await _ensureWebClientInstalled();
    await _startStaticServer();
    return '$_resolvedIp:$port';
  }

  String get webClientUrl {
    if (_staticServerSocket == null) return '';
    return 'http://$_resolvedIp:$httpPort';
  }

  Future<void> stop() async {
    for (final ws in _clients.values) {
      try { await ws.close(); } catch (_) {}
    }
    _clients.clear();
    await _wsServerSocket?.close();
    await _staticServerSocket?.close();
    _wsServerSocket   = null;
    _staticServerSocket = null;
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

  // ── WebSocket server (manual HTTP upgrade) ─────────────────────────────────

  Future<void> _handleWsSocket(Socket socket) async {
    final headers = await _readHeaders(socket);
    if (headers == null) { socket.destroy(); return; }

    final isUpgrade = (headers['upgrade'] ?? '').toLowerCase() == 'websocket';
    if (!isUpgrade) {
      // Health-check ping.
      _writeRaw(socket,
        'HTTP/1.1 200 OK\r\n'
        'Access-Control-Allow-Origin: *\r\n'
        'Content-Type: text/plain\r\n'
        'Content-Length: 27\r\n'
        'Connection: close\r\n'
        '\r\n'
        'YoLoIT collaboration server',
      );
      await socket.close();
      return;
    }

    final key = headers['sec-websocket-key'];
    if (key == null) { socket.destroy(); return; }

    // Compute Sec-WebSocket-Accept
    final accept = base64.encode(
      sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
          .bytes,
    );
    _writeRaw(socket,
      'HTTP/1.1 101 Switching Protocols\r\n'
      'Upgrade: websocket\r\n'
      'Connection: Upgrade\r\n'
      'Sec-WebSocket-Accept: $accept\r\n'
      '\r\n',
    );

    final ws = WebSocket.fromUpgradedSocket(socket, serverSide: true);
    final clientId = 'c_${DateTime.now().millisecondsSinceEpoch}';
    _clients[clientId] = ws;

    ws.listen(
      (raw) {
        final msg = SyncMessage.decode(raw);
        if (msg == null) return;
        onClientMessage(clientId, msg);
        if (msg.type.startsWith('delta.')) broadcastRaw(msg, exclude: clientId);
      },
      onDone:        () => _onDisconnect(clientId),
      onError:       (_) => _onDisconnect(clientId),
      cancelOnError: true,
    );
    broadcastRaw(SyncMessage.connected(clientId, 'Remote'));
  }

  void _onDisconnect(String clientId) {
    _clients.remove(clientId);
    broadcastRaw(SyncMessage.disconnected(clientId));
  }

  // ── Static HTTP file server ────────────────────────────────────────────────

  Future<void> _startStaticServer() async {
    final webDir = await _findWebClientDir();
    if (webDir == null) return;
    try {
      _staticServerSocket = await ServerSocket.bind(
          InternetAddress.anyIPv4, httpPort);
      _staticServerSocket!.listen(
        (s) => _serveStaticSocket(s, webDir).catchError((_) { _destroySocket(s); }),
        onError: (_) {},
      );
    } catch (_) {
      _staticServerSocket = null;
    }
  }

  static Future<void> _serveStaticSocket(Socket socket, String webDir) async {
    final headers = await _readHeaders(socket);
    if (headers == null) { socket.destroy(); return; }

    final method = headers['_method'] ?? 'GET';
    var path     = headers['_path']   ?? '/';

    if (method == 'OPTIONS') {
      _writeRaw(socket,
        'HTTP/1.1 204 No Content\r\n'
        'Access-Control-Allow-Origin: *\r\n'
        'Access-Control-Allow-Methods: GET, OPTIONS\r\n'
        'Access-Control-Allow-Headers: Content-Type\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await socket.close();
      return;
    }

    if (path == '/' || path.isEmpty || !path.contains('.')) path = '/index.html';
    final safePath = Uri.decodeFull(path.split('?').first)
        .replaceAll(RegExp(r'\.\.[\\/]'), '');

    var file = File('$webDir$safePath');
    if (!await file.exists()) file = File('$webDir/index.html');

    final bytes    = await file.readAsBytes();
    final mimeStr  = _mimeString(safePath);

    _writeRaw(socket,
      'HTTP/1.1 200 OK\r\n'
      'Access-Control-Allow-Origin: *\r\n'
      'Cache-Control: no-cache\r\n'
      'Content-Type: $mimeStr\r\n'
      'Content-Length: ${bytes.length}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    socket.add(bytes);
    await socket.flush();
    await socket.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Reads HTTP request headers from [socket].
  /// Returns a map with lowercased header names + '_method' and '_path' keys.
  /// Returns null if the socket closes or sends malformed data.
  static Future<Map<String, String>?> _readHeaders(Socket socket) async {
    final buf = <int>[];
    final end = [13, 10, 13, 10]; // \r\n\r\n
    try {
      await for (final chunk in socket) {
        buf.addAll(chunk);
        if (buf.length >= 4) {
          final tail = buf.sublist(buf.length - 4);
          if (_listEquals(tail, end)) break;
        }
        if (buf.length > 65536) return null; // too large — reject
      }
    } catch (_) {
      return null;
    }

    final text  = utf8.decode(buf, allowMalformed: true);
    final lines = text.split('\r\n');
    if (lines.isEmpty) return null;

    final result = <String, String>{};
    final requestParts = lines[0].split(' ');
    result['_method'] = requestParts.isNotEmpty ? requestParts[0] : 'GET';
    result['_path']   = requestParts.length > 1  ? requestParts[1] : '/';

    for (int i = 1; i < lines.length; i++) {
      final colon = lines[i].indexOf(':');
      if (colon < 0) continue;
      final name  = lines[i].substring(0, colon).trim().toLowerCase();
      final value = lines[i].substring(colon + 1).trim();
      result[name] = value;
    }
    return result;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static void _writeRaw(Socket socket, String data) {
    try { socket.add(utf8.encode(data)); } catch (_) {}
  }

  static void _destroySocket(Socket s) {
    try { s.destroy(); } catch (_) {}
  }

  static String _mimeString(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'html' => 'text/html; charset=utf-8',
      'js'   => 'application/javascript; charset=utf-8',
      'css'  => 'text/css; charset=utf-8',
      'json' => 'application/json',
      'png'  => 'image/png',
      'ico'  => 'image/x-icon',
      'svg'  => 'image/svg+xml',
      'wasm' => 'application/wasm',
      _      => 'application/octet-stream',
    };
  }

  // ── Web client installation ────────────────────────────────────────────────

  static Future<void> _ensureWebClientInstalled() async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final dest = '$home/.yoloit/web_client';
    if (await File('$dest/index.html').exists()) return;

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

  static Future<String?> _findWebClientDir() async {
    final home   = Platform.environment['HOME'] ?? '';
    final exe    = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;

    final fixed = [
      '$appDir/../Resources/web_client',
      '$appDir/web_client',
      '$home/.yoloit/web_client',
      '${Directory.current.path}/build/web',
    ];
    for (final path in fixed) {
      if (await File('$path/index.html').exists()) return _resolved(path);
    }
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

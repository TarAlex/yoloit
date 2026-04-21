import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../collaboration_ports.dart';
import '../model/sync_message.dart';

/// WebSocket server (port [port]) + static HTTP server (port [httpPort]).
///
/// Uses plain [ServerSocket] — NOT [HttpServer] — to avoid a macOS/Dart bug
/// where dart:_http calls setOption(TCP_NODELAY) on accepted sockets and
/// gets errno=22 (EINVAL) for connections coming in on the LAN interface.
///
/// WebSocket frames are parsed manually so the socket's stream subscription
/// is never cancelled (cancelling it after reading headers permanently moves
/// the stream to _STATE_CANCELED, preventing WebSocket.fromUpgradedSocket
/// from re-subscribing — "Bad state: Stream has already been listened to").
class CollaborationServer {
  CollaborationServer({
    required this.onClientMessage,
    this.port = kDefaultWsPort,
    this.httpPort = kDefaultHttpPort,
  });

  final void Function(String clientId, SyncMessage msg) onClientMessage;
  final int port;
  final int httpPort;

  ServerSocket? _wsServerSocket;
  ServerSocket? _staticServerSocket;
  final Map<String, _WsClient> _clients = {};
  String _resolvedIp = '127.0.0.1';

  bool get isRunning => _wsServerSocket != null;
  int get clientCount => _clients.length;

  /// Returns the address string "ip:port" of the WS server.
  Future<String> start() async {
    _wsServerSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    try {
      _wsServerSocket!.listen((s) {
        try {
          _handleWsSocket(s);
        } catch (_) {
          _destroySocket(s);
        }
      }, onError: (_) {});
      _resolvedIp = await _localIp();
      await _ensureWebClientInstalled();
      await _startStaticServer();
      return '$_resolvedIp:$port';
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  /// URL to share with remote devices on the same LAN.
  String get webClientUrl {
    if (_staticServerSocket == null) return '';
    return Uri(
      scheme: 'http',
      host: _resolvedIp,
      port: httpPort,
      queryParameters: {'wsPort': '$port'},
    ).toString();
  }

  /// URL to open in a browser on THIS machine (avoids macOS self-connect bug).
  String get localUrl {
    if (_staticServerSocket == null) return '';
    return Uri(
      scheme: 'http',
      host: 'localhost',
      port: httpPort,
      queryParameters: {'wsPort': '$port'},
    ).toString();
  }

  Future<void> stop() async {
    for (final client in _clients.values) {
      try {
        client.closeNow();
      } catch (_) {}
    }
    _clients.clear();
    await _wsServerSocket?.close();
    await _staticServerSocket?.close();
    _wsServerSocket = null;
    _staticServerSocket = null;
  }

  void broadcastRaw(SyncMessage msg, {String? exclude}) {
    final encoded = msg.encode();
    for (final entry in _clients.entries) {
      if (entry.key == exclude) continue;
      try {
        entry.value.send(encoded);
      } catch (_) {}
    }
  }

  void sendTo(String clientId, SyncMessage msg) {
    try {
      _clients[clientId]?.send(msg.encode());
    } catch (_) {}
  }

  // ── WebSocket server (single subscription, manual frame parsing) ───────────

  /// Sets up a single [socket.listen] that handles both:
  ///  1. HTTP header phase  → parses headers, sends 101 upgrade
  ///  2. WebSocket phase    → decodes frames, dispatches messages
  ///
  /// We never cancel the stream subscription so the stream never enters
  /// _STATE_CANCELED (which would block any future listen call).
  void _handleWsSocket(Socket socket) {
    final buf = <int>[]; // accumulates header bytes
    bool upgraded = false;
    String? clientId;
    _WsClient? client;

    socket.listen(
      (chunk) {
        if (!upgraded) {
          // ── Header phase ──────────────────────────────────────────────────
          buf.addAll(chunk);

          // Find \r\n\r\n
          int? endIdx;
          for (int i = 0; i <= buf.length - 4; i++) {
            if (buf[i] == 13 &&
                buf[i + 1] == 10 &&
                buf[i + 2] == 13 &&
                buf[i + 3] == 10) {
              endIdx = i + 4;
              break;
            }
          }
          if (endIdx == null) {
            if (buf.length > 65536) socket.destroy();
            return; // need more data
          }

          final headers = _parseHeaders(buf.sublist(0, endIdx));
          final leftover = buf.sublist(endIdx);

          final isUpgrade =
              (headers['upgrade'] ?? '').toLowerCase() == 'websocket';

          if (!isUpgrade) {
            // Health-check ping
            _writeRaw(
              socket,
              'HTTP/1.1 200 OK\r\n'
              'Access-Control-Allow-Origin: *\r\n'
              'Content-Type: text/plain\r\n'
              'Content-Length: 27\r\n'
              'Connection: close\r\n'
              '\r\n'
              'YoLoIT collaboration server',
            );
            // flush/close can throw on LAN sockets (macOS EINVAL); swallow.
            socket.flush().catchError((_) {}).whenComplete(() {
              try { socket.destroy(); } catch (_) {}
            });
            return;
          }

          final key = headers['sec-websocket-key'];
          if (key == null) {
            socket.destroy();
            return;
          }

          // Compute Sec-WebSocket-Accept
          final accept = base64.encode(
            sha1
                .convert(
                  utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'),
                )
                .bytes,
          );
          _writeRaw(
            socket,
            'HTTP/1.1 101 Switching Protocols\r\n'
            'Upgrade: websocket\r\n'
            'Connection: Upgrade\r\n'
            'Sec-WebSocket-Accept: $accept\r\n'
            '\r\n',
          );

          upgraded = true;
          clientId = 'c_${DateTime.now().millisecondsSinceEpoch}';
          client = _WsClient(socket);
          _clients[clientId!] = client!;

          if (leftover.isNotEmpty) {
            _processWsChunk(client!, clientId!, leftover);
          }
          broadcastRaw(SyncMessage.connected(clientId!, 'Remote'));
        } else if (client != null) {
          // ── WebSocket frame phase ─────────────────────────────────────────
          _processWsChunk(client!, clientId!, chunk);
        }
      },
      onDone: () {
        if (clientId != null) _onDisconnect(clientId!);
      },
      onError: (_) {
        if (clientId != null) _onDisconnect(clientId!);
        _destroySocket(socket);
      },
      cancelOnError: true,
    );
  }

  void _processWsChunk(_WsClient client, String clientId, List<int> chunk) {
    for (final text in client.processChunk(chunk)) {
      if (text.isEmpty) {
        if (client.isClosed) {
          _onDisconnect(clientId);
          return;
        }
        continue;
      }
      final msg = SyncMessage.decode(text);
      if (msg == null) continue;
      onClientMessage(clientId, msg);
      if (msg.type.startsWith('delta.')) broadcastRaw(msg, exclude: clientId);
    }
  }

  void _onDisconnect(String clientId) {
    _clients.remove(clientId);
    broadcastRaw(SyncMessage.disconnected(clientId));
  }

  // ── Static HTTP file server ────────────────────────────────────────────────

  Future<void> _startStaticServer() async {
    final webDir = await _findWebClientDir();
    if (webDir == null) return;
    _staticServerSocket = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      httpPort,
    );
    _staticServerSocket!.listen(
      (socket) => _serveHttpSocket(socket, webDir).catchError((_) {
        try { socket.destroy(); } catch (_) {}
      }),
      onError: (_) {},
    );
    // Trigger macOS "Local Network" privacy dialog.  On macOS 12+ the OS
    // silently kills accepted sockets from LAN IPs until the user grants
    // Local Network access.  The dialog ONLY appears when the app makes an
    // OUTGOING connection to a LAN address.  We do a fire-and-forget connect
    // to ourselves via the LAN IP (not localhost) so the OS shows the prompt
    // on first launch; subsequent launches are already approved and succeed.
    unawaited(_triggerLocalNetworkPermission());
  }

  /// Fire-and-forget: connect to our own HTTP port via the LAN IP so macOS
  /// shows the Local Network privacy alert.  Errors are expected and silently
  /// swallowed; the only purpose is to trigger the OS permission dialog.
  Future<void> _triggerLocalNetworkPermission() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final ip = _resolvedIp;
    if (ip == null || ip == 'localhost' || ip == '127.0.0.1') return;
    try {
      final s = await Socket.connect(
        ip, httpPort,
        timeout: const Duration(seconds: 3),
      );
      await s.close();
    } catch (_) {
      // Expected on first launch; the dialog will have been shown.
    }
  }

  /// Serves one HTTP request on [socket] using the same stream-listener pattern
  /// as [_handleWsSocket] — no `await for`, no subscription cancel.
  static Future<void> _serveHttpSocket(Socket socket, String webDir) async {
    final done = Completer<void>();
    final buf = <int>[];

    socket.listen(
      (chunk) {
        if (done.isCompleted) return;
        buf.addAll(chunk);
        for (int i = 0; i <= buf.length - 4; i++) {
          if (buf[i] == 13 &&
              buf[i + 1] == 10 &&
              buf[i + 2] == 13 &&
              buf[i + 3] == 10) {
            done.complete();
            return;
          }
        }
        if (buf.length > 65536) done.complete();
      },
      onError: (_) { if (!done.isCompleted) done.complete(); },
      onDone: () { if (!done.isCompleted) done.complete(); },
      cancelOnError: false,
    );

    await done.future;
    if (buf.length < 4) { socket.destroy(); return; }

    final headers = _parseHeaders(buf);
    final method = headers['_method'] ?? 'GET';
    var path = headers['_path'] ?? '/';

    if (method == 'OPTIONS') {
      _writeRaw(
        socket,
        'HTTP/1.1 204 No Content\r\n'
        'Access-Control-Allow-Origin: *\r\n'
        'Access-Control-Allow-Methods: GET, OPTIONS\r\n'
        'Access-Control-Allow-Headers: Content-Type\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      bool optFlushed = false;
      try { await socket.flush(); optFlushed = true; } catch (_) {}
      try {
        await socket.close();
      } catch (_) {
        if (optFlushed) await Future<void>.delayed(const Duration(milliseconds: 400));
        try { socket.destroy(); } catch (_) {}
      }
      return;
    }

    if (path == '/' || path.isEmpty || !path.contains('.'))
      path = '/index.html';
    final safePath = Uri.decodeFull(path.split('?').first)
        .replaceAll(RegExp(r'\.\.[\\/]'), '');

    var file = File('$webDir$safePath');
    if (!await file.exists()) file = File('$webDir/index.html');

    final bytes = await file.readAsBytes();
    final mimeStr = _mimeString(safePath);

    _writeRaw(
      socket,
      'HTTP/1.1 200 OK\r\n'
      'Access-Control-Allow-Origin: *\r\n'
      'Cache-Control: no-store, no-cache, must-revalidate\r\n'
      'Content-Type: $mimeStr\r\n'
      'Content-Length: ${bytes.length}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    try { socket.add(bytes); } catch (_) {}

    // On macOS, socket.close() internally calls shutdown(SHUT_WR) which throws
    // EINVAL (errno=22) for sockets accepted on a non-loopback interface.
    // Fix: flush first, then attempt graceful close; if close() throws, delay
    // before destroy() so the kernel has time to deliver the already-flushed
    // data to the client before RST is sent.
    bool flushed = false;
    try { await socket.flush(); flushed = true; } catch (_) {}
    try {
      await socket.close();
    } catch (_) {
      if (flushed) {
        // Data was flushed to the kernel — give the client time to read it
        // before RST terminates the connection.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      try { socket.destroy(); } catch (_) {}
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parses raw header bytes into a map (lowercase keys + '_method'/'_path').
  static Map<String, String> _parseHeaders(List<int> rawBytes) {
    final text = utf8.decode(rawBytes, allowMalformed: true);
    final lines = text.split('\r\n');
    final result = <String, String>{};
    if (lines.isEmpty) return result;

    final parts = lines[0].split(' ');
    result['_method'] = parts.isNotEmpty ? parts[0] : 'GET';
    result['_path'] = parts.length > 1 ? parts[1] : '/';

    for (int i = 1; i < lines.length; i++) {
      final colon = lines[i].indexOf(':');
      if (colon < 0) continue;
      result[lines[i].substring(0, colon).trim().toLowerCase()] = lines[i]
          .substring(colon + 1)
          .trim();
    }
    return result;
  }

  /// Reads HTTP request headers from [socket] using a single await-for loop.
  /// Safe to use when you won't re-subscribe (e.g. static HTTP handler).
  static Future<Map<String, String>?> _readHeaders(Socket socket) async {
    final buf = <int>[];
    try {
      await for (final chunk in socket) {
        buf.addAll(chunk);
        // Search entire buffer for \r\n\r\n (handles split-chunk delivery)
        for (int i = 0; i <= buf.length - 4; i++) {
          if (buf[i] == 13 &&
              buf[i + 1] == 10 &&
              buf[i + 2] == 13 &&
              buf[i + 3] == 10) {
            return _parseHeaders(buf.sublist(0, i + 4));
          }
        }
        if (buf.length > 65536) return null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static void _writeRaw(Socket socket, String data) {
    try {
      socket.add(utf8.encode(data));
    } catch (_) {}
  }

  static void _destroySocket(Socket s) {
    try {
      s.destroy();
    } catch (_) {}
  }

  static String _mimeString(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'html' => 'text/html; charset=utf-8',
      'js' => 'application/javascript; charset=utf-8',
      'css' => 'text/css; charset=utf-8',
      'json' => 'application/json',
      'png' => 'image/png',
      'ico' => 'image/x-icon',
      'svg' => 'image/svg+xml',
      'wasm' => 'application/wasm',
      _ => 'application/octet-stream',
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
    final home = Platform.environment['HOME'] ?? '';
    final exe = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;

    // Release: web client is bundled inside .app/Contents/Resources/web_client
    if (kReleaseMode) {
      final path = '$appDir/../Resources/web_client';
      if (await File('$path/index.html').exists()) return _resolved(path);
      return null;
    }

    // Debug: check well-known dev locations, then walk up to find build/web
    final devCandidates = [
      '$appDir/../Resources/web_client',
      '$appDir/web_client',
      '$home/.yoloit/web_client',
      '${Directory.current.path}/build/web',
    ];
    for (final path in devCandidates) {
      if (await File('$path/index.html').exists()) return _resolved(path);
    }
    // Walk up from executable to find build/web in the repo
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

// ── Manual WebSocket client (no dart:io WebSocket, avoids stream re-sub bug) ──

class _WsClient {
  _WsClient(this._socket);

  final Socket _socket;
  final List<int> _rxBuf = [];
  bool _closed = false;

  bool get isClosed => _closed;

  /// Send a text message as a WebSocket text frame (server→client, unmasked).
  void send(String text) {
    if (_closed) return;
    try {
      _socket.add(_encodeTextFrame(text));
    } catch (_) {}
  }

  /// Send a close frame and destroy the underlying socket.
  void closeNow() {
    if (_closed) return;
    _closed = true;
    try {
      _socket.add(const [0x88, 0x00]); // close frame, no payload
      _socket.destroy();
    } catch (_) {}
  }

  /// Accumulate [chunk] and return all fully received text messages.
  List<String> processChunk(List<int> chunk) {
    _rxBuf.addAll(chunk);
    final messages = <String>[];
    while (true) {
      final result = _tryExtractFrame();
      if (result == null) break;
      messages.add(result);
    }
    return messages;
  }

  /// Tries to decode one complete WebSocket frame from [_rxBuf].
  /// Returns the decoded text ('' for control frames), or null if incomplete.
  String? _tryExtractFrame() {
    if (_rxBuf.length < 2) return null;

    final b0 = _rxBuf[0];
    final b1 = _rxBuf[1];
    final opcode = b0 & 0x0F;
    final masked = (b1 & 0x80) != 0;
    int payloadLen = b1 & 0x7F;
    int offset = 2;

    if (payloadLen == 126) {
      if (_rxBuf.length < 4) return null;
      payloadLen = (_rxBuf[2] << 8) | _rxBuf[3];
      offset = 4;
    } else if (payloadLen == 127) {
      if (_rxBuf.length < 10) return null;
      payloadLen = 0;
      for (int i = 0; i < 8; i++) {
        payloadLen = (payloadLen << 8) | _rxBuf[2 + i];
      }
      offset = 10;
    }

    final maskLen = masked ? 4 : 0;
    final totalLen = offset + maskLen + payloadLen;
    if (_rxBuf.length < totalLen) return null;

    final payload = List<int>.from(_rxBuf.sublist(offset + maskLen, totalLen));
    if (masked) {
      final mask = _rxBuf.sublist(offset, offset + 4);
      for (int i = 0; i < payload.length; i++) {
        payload[i] ^= mask[i % 4];
      }
    }

    _rxBuf.removeRange(0, totalLen);

    switch (opcode) {
      case 0x8: // Close
        _closed = true;
        try {
          _socket.add(const [0x88, 0x00]);
          _socket.close();
        } catch (_) {}
        return '';
      case 0x9: // Ping → Pong
        try {
          _socket.add(const [0x8A, 0x00]);
        } catch (_) {}
        return '';
      case 0xA: // Pong
        return '';
      case 0x1: // Text
      case 0x2: // Binary (treated as UTF-8 text)
        return utf8.decode(payload, allowMalformed: true);
      default:
        return '';
    }
  }

  static List<int> _encodeTextFrame(String text) {
    final payload = utf8.encode(text);
    final frame = <int>[0x81]; // FIN=1, opcode=1 (text)
    if (payload.length < 126) {
      frame.add(payload.length);
    } else if (payload.length < 65536) {
      frame.add(126);
      frame.add((payload.length >> 8) & 0xFF);
      frame.add(payload.length & 0xFF);
    } else {
      frame.add(127);
      for (int i = 7; i >= 0; i--) {
        frame.add((payload.length >> (i * 8)) & 0xFF);
      }
    }
    frame.addAll(payload);
    return frame;
  }
}

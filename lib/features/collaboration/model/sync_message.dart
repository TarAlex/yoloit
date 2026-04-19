import 'dart:convert';

/// Lightweight JSON-serialisable sync message that replaces the protobuf
/// generated code.  All fields use plain Dart types so no codegen is needed.
///
/// Message types:
///   snapshot      – full canvas state (positions, sizes, hidden)
///   delta.move    – a single node was moved
///   delta.resize  – a single node was resized
///   delta.toggle  – a single node was hidden/shown
///   hello         – guest handshake
///   connected     – server notifies others of new peer
///   disconnected  – peer left
class SyncMessage {
  const SyncMessage({required this.type, required this.payload, this.senderId = ''});

  final String type;
  final String senderId;
  final Map<String, dynamic> payload;

  // ── Type constants ─────────────────────────────────────────────────────────

  static const kSnapshot      = 'snapshot';
  static const kDeltaMove     = 'delta.move';
  static const kDeltaResize   = 'delta.resize';
  static const kDeltaToggle   = 'delta.toggle';
  static const kHello         = 'hello';
  static const kConnected     = 'connected';
  static const kDisconnected  = 'disconnected';
  /// Host → guest: rich content update for a single node.
  static const kNodeUpdate    = 'node.update';
  /// Guest → host: keyboard input for a terminal node.
  static const kTerminalInput = 'terminal.input';

  // ── Factories ──────────────────────────────────────────────────────────────

  factory SyncMessage.snapshot({
    required Map<String, List<double>> positions,
    required Map<String, List<double>> sizes,
    required List<String> hidden,
    required List<String> hiddenTypes,
    List<Map<String, dynamic>> connections = const [],
    Map<String, Map<String, dynamic>> nodeContent = const {},
    String senderId = 'host',
  }) => SyncMessage(
    type: kSnapshot, senderId: senderId,
    payload: {
      'positions':   positions,
      'sizes':       sizes,
      'hidden':      hidden,
      'hiddenTypes': hiddenTypes,
      'connections': connections,
      'nodeContent': nodeContent,
    },
  );

  factory SyncMessage.move(String nodeId, double x, double y, {String senderId = 'host'}) =>
      SyncMessage(type: kDeltaMove, senderId: senderId, payload: {'id': nodeId, 'x': x, 'y': y});

  factory SyncMessage.resize(String nodeId, double w, double h, {String senderId = 'host'}) =>
      SyncMessage(type: kDeltaResize, senderId: senderId, payload: {'id': nodeId, 'w': w, 'h': h});

  factory SyncMessage.toggle(String nodeId, {required bool hidden, String senderId = 'host'}) =>
      SyncMessage(type: kDeltaToggle, senderId: senderId, payload: {'id': nodeId, 'hidden': hidden});

  factory SyncMessage.hello({required String clientId, required String clientName}) =>
      SyncMessage(type: kHello, senderId: clientId, payload: {'id': clientId, 'name': clientName});

  factory SyncMessage.connected(String clientId, String clientName) =>
      SyncMessage(type: kConnected, senderId: 'server', payload: {'id': clientId, 'name': clientName});

  factory SyncMessage.disconnected(String clientId) =>
      SyncMessage(type: kDisconnected, senderId: 'server', payload: {'id': clientId});

  factory SyncMessage.nodeUpdate(String nodeId, Map<String, dynamic> content,
      {String senderId = 'host'}) =>
      SyncMessage(type: kNodeUpdate, senderId: senderId, payload: {'id': nodeId, 'content': content});

  factory SyncMessage.terminalInput(String nodeId, String data,
      {required String senderId}) =>
      SyncMessage(type: kTerminalInput, senderId: senderId,
          payload: {'id': nodeId, 'data': data});

  // ── Serialisation ──────────────────────────────────────────────────────────

  String encode() => jsonEncode({'type': type, 'from': senderId, 'payload': payload});

  static SyncMessage? decode(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      // Support both wrapped ({"type","payload":{..}}) and flat ({"type","name",...}) messages.
      var payload = (m['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (payload.isEmpty && m['type'] == kHello) {
        // Flat hello: {"type":"hello","name":"X"} → wrap into payload format.
        payload = Map<String, dynamic>.from(m)..remove('type')..remove('from');
      }
      return SyncMessage(
        type:     m['type'] as String,
        senderId: (m['from'] as String?) ?? '',
        payload:  payload,
      );
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter/foundation.dart';

enum CollaborationMode { idle, hosting, connected }

/// Identifies a connected remote peer (from the host's perspective).
@immutable
class PeerInfo {
  const PeerInfo({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  /// Hex colour string (e.g. `#60A5FA`) assigned to this peer.
  final String color;

  PeerInfo copyWith({String? name, String? color}) => PeerInfo(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is PeerInfo && other.id == id && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(id, name, color);
}

@immutable
class CollaborationState {
  const CollaborationState({
    this.mode = CollaborationMode.idle,
    this.address = '',
    this.webClientUrl = '',
    this.localUrl = '',
    this.peerCount = 0,
    this.error = '',
    this.peers = const {},
    this.startingHost = false,
    this.encryptionEnabled = false,
  });

  final CollaborationMode mode;

  /// For host: "192.168.1.10:40401". For client: the host address used.
  final String address;

  /// HTTP URL to share with REMOTE devices on the LAN (host mode only).
  final String webClientUrl;

  /// HTTP URL to open in a browser on THIS machine (uses localhost).
  final String localUrl;

  /// Number of currently connected remote peers.
  final int peerCount;

  /// Non-empty when an error occurred (e.g., connection refused).
  final String error;

  /// Connected peers keyed by client id (host perspective).
  /// Includes name and assigned colour for cursor/presence display.
  final Map<String, PeerInfo> peers;

  /// True while the host server is probing ports / retrying startup.
  final bool startingHost;

  /// Whether E2EE (AES-256-GCM) is active for this session.
  final bool encryptionEnabled;

  bool get isIdle => mode == CollaborationMode.idle && !startingHost;
  bool get isHosting => mode == CollaborationMode.hosting;
  bool get isGuest => mode == CollaborationMode.connected;
  bool get isStartingHost => startingHost;

  CollaborationState copyWith({
    CollaborationMode? mode,
    String? address,
    String? webClientUrl,
    String? localUrl,
    int? peerCount,
    String? error,
    Map<String, PeerInfo>? peers,
    bool? startingHost,
    bool? encryptionEnabled,
  }) => CollaborationState(
    mode: mode ?? this.mode,
    address: address ?? this.address,
    webClientUrl: webClientUrl ?? this.webClientUrl,
    localUrl: localUrl ?? this.localUrl,
    peerCount: peerCount ?? this.peerCount,
    error: error ?? this.error,
    peers: peers ?? this.peers,
    startingHost: startingHost ?? this.startingHost,
    encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
  );
}

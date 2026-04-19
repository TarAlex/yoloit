import 'package:flutter/foundation.dart';

enum CollaborationMode { idle, hosting, connected }

@immutable
class CollaborationState {
  const CollaborationState({
    this.mode         = CollaborationMode.idle,
    this.address      = '',
    this.webClientUrl = '',
    this.localUrl     = '',
    this.peerCount    = 0,
    this.error        = '',
    this.peers        = const {},
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

  /// Peer client ids and names currently connected (host perspective).
  final Map<String, String> peers;

  bool get isIdle     => mode == CollaborationMode.idle;
  bool get isHosting  => mode == CollaborationMode.hosting;
  bool get isGuest    => mode == CollaborationMode.connected;

  CollaborationState copyWith({
    CollaborationMode? mode,
    String?            address,
    String?            webClientUrl,
    String?            localUrl,
    int?               peerCount,
    String?            error,
    Map<String, String>? peers,
  }) => CollaborationState(
    mode:         mode         ?? this.mode,
    address:      address      ?? this.address,
    webClientUrl: webClientUrl ?? this.webClientUrl,
    localUrl:     localUrl     ?? this.localUrl,
    peerCount:    peerCount    ?? this.peerCount,
    error:        error        ?? this.error,
    peers:        peers        ?? this.peers,
  );
}

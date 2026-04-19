import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../mindmap/bloc/mindmap_cubit.dart';
import '../../mindmap/bloc/mindmap_state.dart';
import '../generated/mindmap_sync.pb.dart';
import '../services/collaboration_client.dart';
import '../services/collaboration_server.dart';
import 'collaboration_state.dart';

/// Orchestrates real-time collaboration:
/// - **Host mode**: starts a [CollaborationServer], subscribes to [MindMapCubit]
///   state changes, and broadcasts proto snapshots/deltas to all clients.
/// - **Guest mode**: starts a [CollaborationClient], receives proto messages,
///   and applies them to the local [MindMapCubit].
class CollaborationCubit extends Cubit<CollaborationState> {
  CollaborationCubit({required this.mindMapCubit})
      : super(const CollaborationState());

  final MindMapCubit mindMapCubit;

  CollaborationServer? _server;
  CollaborationClient? _client;
  StreamSubscription<MindMapState>? _stateSub;

  MindMapState? _lastBroadcast;

  // ── Host ─────────────────────────────────────────────────────────────────

  /// Starts the WebSocket server and begins broadcasting mindmap state.
  Future<void> startHosting({int port = 40401}) async {
    if (!state.isIdle) return;
    emit(state.copyWith(error: ''));
    try {
      _server = CollaborationServer(
        port:          port,
        onClientEvent: _onClientEvent,
      );
      final address = await _server!.start();

      // Subscribe to MindMapCubit changes and broadcast deltas.
      _stateSub = mindMapCubit.stream.listen(_onMindMapStateChanged);

      emit(state.copyWith(
        mode:    CollaborationMode.hosting,
        address: address,
      ));
    } catch (e) {
      _server = null;
      emit(state.copyWith(error: 'Failed to start server: $e'));
    }
  }

  Future<void> stopHosting() async {
    await _server?.stop();
    await _stateSub?.cancel();
    _server   = null;
    _stateSub = null;
    _lastBroadcast = null;
    emit(const CollaborationState());
  }

  // ── Guest ────────────────────────────────────────────────────────────────

  /// Connects to a host at [host]:[port] and mirrors its mindmap state locally.
  Future<void> connect(String host, {int port = 40401}) async {
    if (!state.isIdle) return;
    emit(state.copyWith(error: ''));
    try {
      _client = CollaborationClient(onEnvelope: _onEnvelopeFromHost);
      await _client!.connect(host, port);
      emit(state.copyWith(
        mode:    CollaborationMode.connected,
        address: '$host:$port',
      ));
    } catch (e) {
      _client = null;
      emit(state.copyWith(error: 'Connection failed: $e'));
    }
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    emit(const CollaborationState());
  }

  // ── State → proto (host side) ─────────────────────────────────────────────

  void _onMindMapStateChanged(MindMapState mmState) {
    final prev = _lastBroadcast;
    _lastBroadcast = mmState;
    if (_server == null || _server!.clientCount == 0) return;

    if (prev == null) {
      // First broadcast — send full snapshot.
      _server!.broadcastSnapshot(_makeSnapshot(mmState));
      return;
    }

    // Send fine-grained delta events for changed positions and sizes.
    for (final entry in mmState.positions.entries) {
      final id  = entry.key;
      final pos = entry.value;
      final old = prev.positions[id];
      if (old == null || old.dx != pos.dx || old.dy != pos.dy) {
        _server!.broadcastDelta(SyncEnvelope(
          senderId: 'host',
          delta: DeltaEvent(
            moved: NodeMoved(nodeId: id, x: pos.dx.toFloat(), y: pos.dy.toFloat()),
          ),
        ));
      }
    }
    for (final entry in mmState.sizes.entries) {
      final id  = entry.key;
      final sz  = entry.value;
      final old = prev.sizes[id];
      if (old == null || old.width != sz.width || old.height != sz.height) {
        _server!.broadcastDelta(SyncEnvelope(
          senderId: 'host',
          delta: DeltaEvent(
            resized: NodeResized(
              nodeId: id,
              width:   sz.width.toFloat(),
              height:  sz.height.toFloat(),
            ),
          ),
        ));
      }
    }
    // Hidden set changes.
    final newHidden = mmState.hidden.difference(prev.hidden);
    final nowShown  = prev.hidden.difference(mmState.hidden);
    for (final id in newHidden) {
      _server!.broadcastDelta(SyncEnvelope(
        senderId: 'host',
        delta: DeltaEvent(toggled: NodeToggled(nodeId: id, hidden: true)),
      ));
    }
    for (final id in nowShown) {
      _server!.broadcastDelta(SyncEnvelope(
        senderId: 'host',
        delta: DeltaEvent(toggled: NodeToggled(nodeId: id, hidden: false)),
      ));
    }
  }

  SyncEnvelope _makeSnapshot(MindMapState mm) => SyncEnvelope(
    senderId: 'host',
    snapshot: StateSnapshot(
      positions:    mm.positions.map((k, v) => MapEntry(k, Vec2(x: v.dx.toFloat(), y: v.dy.toFloat()))),
      sizes:        mm.sizes.map((k, v) => MapEntry(k, Vec2(x: v.width.toFloat(), y: v.height.toFloat()))),
      hidden:       mm.hidden.toList(),
      hiddenTypes: mm.hiddenTypes.toList(),
    ),
  );

  // ── Proto → state (guest side) ─────────────────────────────────────────────

  void _onEnvelopeFromHost(SyncEnvelope env) {
    if (env.hasSnapshot()) {
      _applySnapshot(env.snapshot);
    } else if (env.hasDelta()) {
      _applyDelta(env.delta);
    } else if (env.hasDisconnected()) {
      // Server disconnected — fall back to idle.
      disconnect();
    }
  }

  void _applySnapshot(StateSnapshot snap) {
    final positions = snap.positions.map(
        (k, v) => MapEntry(k, Offset(v.x.toDouble(), v.y.toDouble())));
    final sizes = snap.sizes.map(
        (k, v) => MapEntry(k, Size(v.x.toDouble(), v.y.toDouble())));
    mindMapCubit.applyRemoteSnapshot(
      positions:   positions,
      sizes:       sizes,
      hidden:      snap.hidden.toSet(),
      hiddenTypes: snap.hiddenTypes.toSet(),
    );
  }

  void _applyDelta(DeltaEvent delta) {
    if (delta.hasMoved()) {
      final m = delta.moved;
      mindMapCubit.applyRemoteMove(
          m.nodeId, Offset(m.x.toDouble(), m.y.toDouble()));
    } else if (delta.hasResized()) {
      final r = delta.resized;
      mindMapCubit.applyRemoteResize(
          r.nodeId, Size(r.width.toDouble(), r.height.toDouble()));
    } else if (delta.hasToggled()) {
      final t = delta.toggled;
      if (t.hidden) {
        mindMapCubit.hideNode(t.nodeId);
      } else {
        mindMapCubit.showNode(t.nodeId);
      }
    }
  }

  // ── Client events received by host ────────────────────────────────────────

  void _onClientEvent(SyncEnvelope env) {
    if (env.hasHello()) {
      final h   = env.hello;
      final map = Map<String, String>.from(state.peers)
        ..[h.clientId] = h.clientName;
      emit(state.copyWith(peers: map, peerCount: map.length));
      // Send full snapshot to the newly connected client.
      _server!.broadcastSnapshot(_makeSnapshot(mindMapCubit.state));
    } else if (env.hasDisconnected()) {
      final id  = env.disconnected.clientId;
      final map = Map<String, String>.from(state.peers)..remove(id);
      emit(state.copyWith(peers: map, peerCount: map.length));
    } else if (env.hasDelta()) {
      // Client is moving a node — apply locally and re-broadcast.
      _applyDelta(env.delta);
    }
  }

  @override
  Future<void> close() async {
    await stopHosting();
    await disconnect();
    await super.close();
  }
}

extension _DoubleToFloat on double {
  double toFloat() => this; // proto float is 32-bit, but Dart double is fine here
}

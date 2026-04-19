import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../mindmap/bloc/mindmap_cubit.dart';
import '../../mindmap/bloc/mindmap_state.dart';
import '../model/sync_message.dart';
import '../services/collaboration_client.dart';
import '../services/collaboration_server_platform.dart';
import 'collaboration_state.dart';

/// Orchestrates real-time collaboration over a local WebSocket connection.
///
/// **Host mode**: starts [CollaborationServer], subscribes to [MindMapCubit]
/// changes, and broadcasts JSON snapshots/deltas to all connected clients.
///
/// **Guest mode**: starts [CollaborationClient], receives JSON messages, and
/// applies them to the local [MindMapCubit].
class CollaborationCubit extends Cubit<CollaborationState> {
  CollaborationCubit({required this.mindMapCubit})
      : super(const CollaborationState());

  final MindMapCubit mindMapCubit;

  CollaborationServer? _server;
  CollaborationClient? _client;
  StreamSubscription<MindMapState>? _stateSub;
  MindMapState? _lastBroadcast;

  // ── Host ─────────────────────────────────────────────────────────────────

  Future<void> startHosting({int port = 40401}) async {
    if (!state.isIdle) return;
    emit(state.copyWith(error: ''));
    try {
      _server = CollaborationServer(
        port:            port,
        onClientMessage: _onClientMessage,
      );
      final address = await _server!.start();
      _stateSub = mindMapCubit.stream.listen(_onMindMapStateChanged);
      emit(state.copyWith(
        mode:         CollaborationMode.hosting,
        address:      address,
        webClientUrl: _server!.webClientUrl,
        localUrl:     _server!.localUrl,
      ));
    } catch (e) {
      _server = null;
      emit(state.copyWith(error: 'Failed to start server: $e'));
    }
  }

  Future<void> stopHosting() async {
    await _server?.stop();
    await _stateSub?.cancel();
    _server        = null;
    _stateSub      = null;
    _lastBroadcast = null;
    emit(const CollaborationState());
  }

  // ── Guest ────────────────────────────────────────────────────────────────

  Future<void> connect(String host, {int port = 40401}) async {
    if (!state.isIdle) return;
    emit(state.copyWith(error: ''));
    try {
      _client = CollaborationClient(onMessage: _onMessageFromHost);
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

  /// Guest: send a node move to the host (used from web/remote canvas).
  void sendGuestMove(String nodeId, Offset pos) {
    _client?.sendMessage(SyncMessage.move(nodeId, pos.dx, pos.dy, senderId: 'guest'));
  }

  /// Guest: send a node resize to the host.
  void sendGuestResize(String nodeId, Size size) {
    _client?.sendMessage(SyncMessage.resize(nodeId, size.width, size.height, senderId: 'guest'));
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    emit(const CollaborationState());
  }

  // ── Host: MindMap → broadcast ─────────────────────────────────────────────

  void _onMindMapStateChanged(MindMapState mmState) {
    final prev = _lastBroadcast;
    _lastBroadcast = mmState;
    if (_server == null || _server!.clientCount == 0) return;

    if (prev == null) {
      _server!.broadcastRaw(_buildSnapshot(mmState));
      return;
    }

    for (final entry in mmState.positions.entries) {
      final old = prev.positions[entry.key];
      if (old == null || old != entry.value) {
        _server!.broadcastRaw(SyncMessage.move(
            entry.key, entry.value.dx, entry.value.dy));
      }
    }
    for (final entry in mmState.sizes.entries) {
      final old = prev.sizes[entry.key];
      if (old == null || old != entry.value) {
        _server!.broadcastRaw(SyncMessage.resize(
            entry.key, entry.value.width, entry.value.height));
      }
    }
    for (final id in mmState.hidden.difference(prev.hidden)) {
      _server!.broadcastRaw(SyncMessage.toggle(id, hidden: true));
    }
    for (final id in prev.hidden.difference(mmState.hidden)) {
      _server!.broadcastRaw(SyncMessage.toggle(id, hidden: false));
    }
  }

  SyncMessage _buildSnapshot(MindMapState mm) => SyncMessage.snapshot(
    positions:   mm.positions.map((k, v) => MapEntry(k, [v.dx, v.dy])),
    sizes:       mm.sizes.map((k, v) => MapEntry(k, [v.width, v.height])),
    hidden:      mm.hidden.toList(),
    hiddenTypes: mm.hiddenTypes.toList(),
  );

  // ── Guest: received from host ─────────────────────────────────────────────

  void _onMessageFromHost(SyncMessage msg) {
    switch (msg.type) {
      case SyncMessage.kSnapshot:
        _applySnapshot(msg.payload);
      case SyncMessage.kDeltaMove:
        _applyMove(msg.payload);
      case SyncMessage.kDeltaResize:
        _applyResize(msg.payload);
      case SyncMessage.kDeltaToggle:
        _applyToggle(msg.payload);
      case SyncMessage.kConnected:
        final map = Map<String, String>.from(state.peers)
          ..[msg.payload['id'] as String] = msg.payload['name'] as String;
        emit(state.copyWith(peers: map, peerCount: map.length));
      case SyncMessage.kDisconnected:
        if (msg.payload['id'] == 'server') {
          disconnect();
        } else {
          final map = Map<String, String>.from(state.peers)
            ..remove(msg.payload['id']);
          emit(state.copyWith(peers: map, peerCount: map.length));
        }
    }
  }

  void _applySnapshot(Map<String, dynamic> p) {
    final posRaw  = (p['positions']  as Map<String, dynamic>?) ?? {};
    final szRaw   = (p['sizes']      as Map<String, dynamic>?) ?? {};
    final hidden  = ((p['hidden']    as List?) ?? []).cast<String>().toSet();
    final hTypes  = ((p['hiddenTypes'] as List?) ?? []).cast<String>().toSet();

    final positions = posRaw.map((k, v) {
      final l = (v as List).cast<num>();
      return MapEntry(k, Offset(l[0].toDouble(), l[1].toDouble()));
    });
    final sizes = szRaw.map((k, v) {
      final l = (v as List).cast<num>();
      return MapEntry(k, Size(l[0].toDouble(), l[1].toDouble()));
    });
    mindMapCubit.applyRemoteSnapshot(
      positions:   positions,
      sizes:       sizes,
      hidden:      hidden,
      hiddenTypes: hTypes,
    );
  }

  void _applyMove(Map<String, dynamic> p) => mindMapCubit.applyRemoteMove(
    p['id'] as String,
    Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
  );

  void _applyResize(Map<String, dynamic> p) => mindMapCubit.applyRemoteResize(
    p['id'] as String,
    Size((p['w'] as num).toDouble(), (p['h'] as num).toDouble()),
  );

  void _applyToggle(Map<String, dynamic> p) {
    final id     = p['id'] as String;
    final hidden = p['hidden'] as bool;
    if (hidden) {
      mindMapCubit.hideNode(id);
    } else {
      mindMapCubit.showNode(id);
    }
  }

  // ── Host: client messages ─────────────────────────────────────────────────

  void _onClientMessage(String clientId, SyncMessage msg) {
    switch (msg.type) {
      case SyncMessage.kHello:
        final id   = msg.payload['id']   as String;
        final name = msg.payload['name'] as String;
        final map  = Map<String, String>.from(state.peers)..[id] = name;
        emit(state.copyWith(peers: map, peerCount: map.length));
        // Send full snapshot to newly connected client.
        _server!.sendTo(clientId, _buildSnapshot(mindMapCubit.state));
      case SyncMessage.kDeltaMove:
        _applyMove(msg.payload);
      case SyncMessage.kDeltaResize:
        _applyResize(msg.payload);
      case SyncMessage.kDeltaToggle:
        _applyToggle(msg.payload);
      default:
        break;
    }
  }

  @override
  Future<void> close() async {
    await stopHosting();
    await disconnect();
    await super.close();
  }
}

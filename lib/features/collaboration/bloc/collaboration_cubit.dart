import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../mindmap/bloc/mindmap_cubit.dart';
import '../../mindmap/bloc/mindmap_state.dart';
import '../../mindmap/model/mindmap_node_model.dart';
import '../../terminal/data/terminal_output_bus.dart';
import '../../terminal/models/agent_session.dart';
import '../../runs/models/run_session.dart';
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
  /// [onTerminalInput] receives (sessionId, data) when a browser guest sends
  /// keyboard input to a terminal.  Pass [PtyService.instance.write] on the
  /// host (macOS); leave null on web guests where PtyService is unavailable.
  ///
  /// [ensureNodesPopulated] is called before sending the first snapshot when
  /// [mindMapCubit] has no positions (user hasn't opened Map View yet).
  /// The host (macOS app.dart) provides a callback that reads workspace and
  /// terminal state and calls [mindMapCubit.updateNodes]; leave null on web.
  CollaborationCubit({
    required this.mindMapCubit,
    this.ensureNodesPopulated,
    this.onTerminalInput,
  }) : super(const CollaborationState());

  final MindMapCubit mindMapCubit;
  final Future<void> Function()? ensureNodesPopulated;
  final void Function(String sessionId, String data)? onTerminalInput;

  CollaborationServer? _server;
  CollaborationClient? _client;
  StreamSubscription<MindMapState>? _stateSub;
  StreamSubscription<(String, String)>? _terminalSub;
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
      // Stream live terminal output to all connected browser guests.
      _terminalSub = TerminalOutputBus.instance.stream.listen(_onTerminalData);
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
    await _terminalSub?.cancel();
    _server        = null;
    _stateSub      = null;
    _terminalSub   = null;
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
    connections: mm.connections.map((c) => {
      'from': c.fromId,
      'to':   c.toId,
      'style': c.style.name,
      'color': c.color.toARGB32(),
    }).toList(),
    nodeContent: Map.fromEntries(mm.nodes.map((n) {
      final content = _serializeNodeContent(n);
      return MapEntry(n.id, content);
    })),
  );

  Map<String, dynamic> _serializeNodeContent(MindMapNodeData node) {
    return switch (node) {
      AgentNodeData d => {
        'type':   'agent',
        'name':   d.session.customName ?? d.session.id,
        'status': d.session.status.name,
        'isRunning': d.isRunning,
        'workspaceId': d.workspaceId,
        'lastLines': d.session.lastLines(80),
      },
      WorkspaceNodeData d => {
        'type': 'workspace',
        'name': d.workspace.name,
        'path': d.workspace.path,
      },
      SessionNodeData d => {
        'type':   'session',
        'name':   d.session.customName ?? d.session.id,
        'status': d.session.status.name,
        'isRunning': d.session.status == AgentStatus.live,
        'workspaceId': d.workspaceId,
        'lastLines': d.session.lastLines(80),
      },
      RepoNodeData d => {
        'type':   'repo',
        'name':   d.repoName,
        'path':   d.repoPath,
        'branch': d.branch,
      },
      BranchNodeData d => {
        'type':       'branch',
        'name':       d.branch,
        'repoName':   d.repoName,
        'commitHash': d.commitHash,
      },
      EditorNodeData d => {
        'type':     'editor',
        'filePath': d.filePath,
        'language': d.language,
        'content':  d.content.length > 8000
            ? d.content.substring(0, 8000)
            : d.content,
      },
      FilesNodeData d => {
        'type':   'files',
        'repoPath': d.repoPath,
        'files': d.changedFiles.map((f) => {
          'path':   f.path,
          'status': f.status.name,
        }).toList(),
      },
      FileTreeNodeData d => {
        'type':       'tree',
        'workspaceId': d.workspaceId,
        'repoPath':   d.repoPath,
        'repoName':   d.repoName,
      },
      DiffNodeData d => {
        'type':       'diff',
        'workspaceId': d.workspaceId,
        'repoPath':   d.repoPath,
        'repoName':   d.repoName,
      },
      RunNodeData d => {
        'type':      'run',
        'name':      d.session.config.name,
        'status':    d.session.status.name,
        'isRunning': d.session.status == RunStatus.running,
        'lastLines': d.session.output
            .reversed.take(80).toList().reversed
            .map((l) => l.text).toList(),
      },
      MindMapPluginNodeData d => {
        'type':     'plugin',
        'pluginId': d.pluginId,
        'payload':  d.payload,
      },
    };
  }

  /// Streams live terminal output to all connected browser guests.
  void _onTerminalData((String, String) event) {
    if (_server == null || _server!.clientCount == 0) return;
    final (sessionId, plainText) = event;
    // Find the agent node that owns this session.
    final node = mindMapCubit.state.nodes.whereType<AgentNodeData>()
        .cast<AgentNodeData?>()
        .firstWhere((n) => n!.session.id == sessionId, orElse: () => null);
    if (node == null) return;

    final currentContent = _serializeNodeContent(node);
    _server!.broadcastRaw(SyncMessage.nodeUpdate(node.id, currentContent));
  }

  /// Guest: send keyboard input for a terminal to the host.
  void sendTerminalInput(String nodeId, String data) {
    _client?.sendMessage(
      SyncMessage.terminalInput(nodeId, data, senderId: 'guest'),
    );
  }

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
      case SyncMessage.kNodeUpdate:
        final id = msg.payload['id'] as String;
        final content = (msg.payload['content'] as Map<String, dynamic>?) ?? {};
        mindMapCubit.updateNodeContent(id, content);
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
    final connRaw = (p['connections'] as List?) ?? [];
    final ncRaw   = (p['nodeContent'] as Map<String, dynamic>?) ?? {};

    final positions = posRaw.map((k, v) {
      final l = (v as List).cast<num>();
      return MapEntry(k, Offset(l[0].toDouble(), l[1].toDouble()));
    });
    final sizes = szRaw.map((k, v) {
      final l = (v as List).cast<num>();
      return MapEntry(k, Size(l[0].toDouble(), l[1].toDouble()));
    });
    final connections = connRaw.map((raw) {
      final c = raw as Map<String, dynamic>;
      final style = ConnectorStyle.values.firstWhere(
        (s) => s.name == (c['style'] as String? ?? 'solid'),
        orElse: () => ConnectorStyle.solid,
      );
      return MindMapConnection(
        fromId: c['from'] as String,
        toId:   c['to'] as String,
        style:  style,
        color:  Color(c['color'] as int),
      );
    }).toList();
    final nodeContent = ncRaw.map((k, v) =>
        MapEntry(k, (v as Map<String, dynamic>)));

    mindMapCubit.applyRemoteSnapshot(
      positions:   positions,
      sizes:       sizes,
      hidden:      hidden,
      hiddenTypes: hTypes,
      connections: connections,
      nodeContent: nodeContent,
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
        // Populate mind map from workspace/terminal state if not yet done,
        // then send the full snapshot to the newly connected client.
        _sendSnapshotAfterPopulate(clientId);
      case SyncMessage.kDeltaMove:
        _applyMove(msg.payload);
      case SyncMessage.kDeltaResize:
        _applyResize(msg.payload);
      case SyncMessage.kDeltaToggle:
        _applyToggle(msg.payload);
      case SyncMessage.kTerminalInput:
        // Forward keyboard input from browser guest to the actual PTY.
        final nodeId = msg.payload['id'] as String? ?? '';
        final data   = msg.payload['data'] as String? ?? '';
        if (nodeId.isNotEmpty && data.isNotEmpty) {
          onTerminalInput?.call(nodeId, data);
        }
      default:
        break;
    }
  }

  /// Ensures the mind map has nodes populated from the current workspace and
  /// terminal state (for users who haven't opened the Map View yet), then
  /// sends the full snapshot to [clientId].
  Future<void> _sendSnapshotAfterPopulate(String clientId) async {
    if (mindMapCubit.state.positions.isEmpty) {
      await ensureNodesPopulated?.call();
    }
    _server?.sendTo(clientId, _buildSnapshot(mindMapCubit.state));
  }

  @override
  Future<void> close() async {
    await stopHosting();
    await disconnect();
    await super.close();
  }
}

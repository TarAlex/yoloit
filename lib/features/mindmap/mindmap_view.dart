import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/mindmap/mindmap_layout_engine.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/node_registry.dart';
import 'package:yoloit/features/mindmap/plugin/mindmap_plugin_registry.dart';
import 'package:yoloit/features/mindmap/widgets/mindmap_connector.dart';
import 'package:yoloit/features/mindmap/widgets/mindmap_node.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/runs/bloc/run_state.dart';
import 'package:yoloit/features/runs/models/run_session.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';

/// The Miro-like mind-map canvas view.
/// Shows all workspaces, sessions, repos, branches, agents (with live terminals),
/// changed files, and the active editor as interconnected draggable cards.
class MindMapView extends StatefulWidget {
  const MindMapView({super.key});

  @override
  State<MindMapView> createState() => _MindMapViewState();
}

class _MindMapViewState extends State<MindMapView>
    with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late AnimationController _dashCtrl;
  late Animation<double>   _dashAnim;

  @override
  void initState() {
    super.initState();
    _dashCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dashAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_dashCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<MindMapCubit>().loadPersistedPositions();
      if (!mounted) return;
      // Preload persisted session metadata for all non-active workspaces so
      // the mindmap can render their terminals as idle cards.
      final wsState = context.read<WorkspaceCubit>().state;
      if (wsState is WorkspaceLoaded) {
        await context
            .read<TerminalCubit>()
            .loadPersistedMetadataForWorkspaces(
              wsState.workspaces.map((w) => w.id).toList(),
            );
      }
    });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _dashCtrl.dispose();
    super.dispose();
  }

  /// Pans the canvas so [nodeId] is roughly centered on screen.
  void _scrollToNode(String nodeId, MindMapState mmState) {
    final pos = mmState.positions[nodeId];
    if (pos == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final screenSize = renderBox.size;
    const editorW = 460.0;
    const editorH = 348.0;
    final targetX = pos.dx + editorW / 2 - screenSize.width  / 2;
    final targetY = pos.dy + editorH / 2 - screenSize.height / 2;
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    _transformCtrl.value = Matrix4.identity()
      ..scale(scale)
      ..translate(-targetX, -targetY);
  }

  // ── Build node + connection lists from blocs ───────────────────────────

  ({List<MindMapNodeData> nodes, List<MindMapConnection> conns}) _buildData(
    WorkspaceState wsState,
    TerminalState  termState,
    ReviewState    reviewState,
    FileEditorState editorState,
    RunState       runState,
  ) {
    final nodes  = <MindMapNodeData>[];
    final conns  = <MindMapConnection>[];

    if (wsState is! WorkspaceLoaded) return (nodes: nodes, conns: conns);

    for (final ws in wsState.workspaces) {
      final wsNodeId = 'ws:${ws.id}';
      nodes.add(WorkspaceNodeData(id: wsNodeId, workspace: ws));

      // Sessions (terminal sessions) belonging to this workspace.
      // Match by workspaceId when set; fall back to workspacePath prefix when
      // workspaceId is null (older sessions may not have it populated).
      final sessions = termState is TerminalLoaded
          ? termState.allSessions.where((s) {
              if (s.workspaceId != null) return s.workspaceId == ws.id;
              return ws.paths.any((p2) => s.workspacePath.startsWith(p2));
            }).toList()
          : <AgentSession>[];

      for (final session in sessions) {
        // MERGED session+terminal card (single card per session, since sessions
        // are 1:1 with terminals in our data model).
        final agentNodeId = 'agent:${session.id}';
        nodes.add(AgentNodeData(
          id:               agentNodeId,
          session:          session,
          workspaceId:      ws.id,
          workspacePaths:   ws.paths,
          workspaceBranch:  ws.gitBranch,
        ));

        final isLive = session.status == AgentStatus.live;
        final agentConnStyle = isLive ? ConnectorStyle.animated : ConnectorStyle.solid;
        final agentColor     = isLive ? const Color(0xFF34D399) : const Color(0xFF60A5FA);

        // Workspace → session/agent
        conns.add(MindMapConnection(
          fromId: wsNodeId,
          toId:   agentNodeId,
          style:  agentConnStyle,
          color:  agentColor.withAlpha(100),
        ));

        // ── Repos & branches ──────────────────────────────────────────
        // Prefer worktreeContexts; fall back to workspace paths.
        final wt = session.worktreeContexts;
        final repoPaths = <String, String>{}; // repoPath → branchPath (or gitBranch)

        if (wt != null && wt.isNotEmpty) {
          for (final e in wt.entries) {
            repoPaths[e.key] = e.value;
          }
        } else {
          for (final rp in ws.paths) {
            repoPaths[rp] = ws.gitBranch ?? 'main';
          }
        }

        final allBranchNodeIds = <String>[];
        for (final entry in repoPaths.entries) {
          final repoPath     = entry.key;
          final branchRef    = entry.value;
          final repoName     = p.basename(repoPath);
          final repoNodeId   = 'repo:${ws.id}:$repoPath';
          final branchNodeId = 'branch:${ws.id}:$repoPath';

          if (!nodes.any((n) => n.id == repoNodeId)) {
            nodes.add(RepoNodeData(
              id:        repoNodeId,
              sessionId: session.id,
              repoPath:  repoPath,
              repoName:  repoName,
              branch:    p.basename(branchRef),
            ));
          }
          conns.add(MindMapConnection(
            fromId: agentNodeId,
            toId:   repoNodeId,
            style:  ConnectorStyle.solid,
            color:  const Color(0x59C084FC),
          ));

          if (!nodes.any((n) => n.id == branchNodeId)) {
            nodes.add(BranchNodeData(
              id:         branchNodeId,
              repoId:     repoNodeId,
              repoName:   repoName,
              branch:     p.basename(branchRef),
              commitHash: '',
            ));
          }
          conns.add(MindMapConnection(
            fromId: repoNodeId,
            toId:   branchNodeId,
            style:  ConnectorStyle.dashed,
            color:  const Color(0x597C6BFF),
          ));

          allBranchNodeIds.add(branchNodeId);
        }
      }

      // No sessions → show only the workspace card, no repos/branches.
    }

    // Orphan sessions — sessions that don't match any known workspace by id
    // or by any path prefix. Render them anyway so the user sees all terminals.
    if (termState is TerminalLoaded) {
      final existingAgents = nodes.whereType<AgentNodeData>().map((a) => a.session.id).toSet();
      for (final session in termState.allSessions) {
        if (existingAgents.contains(session.id)) continue;
        final agentNodeId = 'agent:${session.id}';
        // Try to match workspace for path fallback
        final matchedWs = wsState.workspaces
            .where((w) => w.id == session.workspaceId ||
                w.paths.any((p2) => session.workspacePath.startsWith(p2)))
            .firstOrNull;
        nodes.add(AgentNodeData(
          id:              agentNodeId,
          session:         session,
          workspaceId:     session.workspaceId ?? '',
          workspacePaths:  matchedWs?.paths ?? const [],
          workspaceBranch: matchedWs?.gitBranch,
        ));

        // Build repos/branches from worktreeContexts; fall back to workspace paths.
        final wt = session.worktreeContexts?.isNotEmpty == true
            ? session.worktreeContexts!
            : (matchedWs != null && matchedWs.paths.isNotEmpty
                ? {for (final rp in matchedWs.paths) rp: matchedWs.gitBranch ?? 'main'}
                : {session.workspacePath: 'main'});
        for (final e in wt.entries) {
          final repoPath   = e.key;
          final branchRef  = e.value;
          final repoName   = p.basename(repoPath);
          final repoNodeId = 'repo:orphan:$repoPath';
          final brNodeId   = 'branch:orphan:$repoPath';
          if (!nodes.any((n) => n.id == repoNodeId)) {
            nodes.add(RepoNodeData(
              id: repoNodeId, sessionId: session.id,
              repoPath: repoPath, repoName: repoName,
              branch: p.basename(branchRef),
            ));
          }
          conns.add(MindMapConnection(
            fromId: agentNodeId, toId: repoNodeId,
            style: ConnectorStyle.solid, color: const Color(0x59C084FC),
          ));
          if (!nodes.any((n) => n.id == brNodeId)) {
            nodes.add(BranchNodeData(
              id: brNodeId, repoId: repoNodeId, repoName: repoName,
              branch: p.basename(branchRef), commitHash: '',
            ));
          }
          conns.add(MindMapConnection(
            fromId: repoNodeId, toId: brNodeId,
            style: ConnectorStyle.dashed, color: const Color(0x597C6BFF),
          ));
        }
      }
    }

    // Changed files (from review state).
    if (reviewState is ReviewLoaded && reviewState.changedFiles.isNotEmpty) {
      final groupedByRepo = <String, List<dynamic>>{};
      for (final f in reviewState.changedFiles) {
        final repo = f.repoPath ?? 'unknown';
        groupedByRepo.putIfAbsent(repo, () => []).add(f);
      }
      for (final entry in groupedByRepo.entries) {
        final filesId = 'files:${entry.key}';
        nodes.add(FilesNodeData(
          id:           filesId,
          sessionId:    '',
          repoPath:     entry.key,
          changedFiles: entry.value.cast(),
        ));
        // Connect from matching branch node if available.
        final branchNode = nodes.whereType<BranchNodeData>()
            .where((b) => b.repoName == p.basename(entry.key))
            .firstOrNull;
        if (branchNode != null) {
          conns.add(MindMapConnection(
            fromId: branchNode.id,
            toId:   filesId,
            style:  ConnectorStyle.dashed,
            color:  const Color(0x406B7898),
          ));
        }
      }
    }

    // File Tree — one card per repo (RepoNode), file browser only.
    final repoNodes = nodes.whereType<RepoNodeData>().toList();
    for (final repo in repoNodes) {
      final treeId = 'tree:${repo.repoPath}';
      final diffId  = 'diff:${repo.repoPath}';
      if (nodes.any((n) => n.id == treeId)) continue;
      nodes.add(FileTreeNodeData(
        id:          treeId,
        workspaceId: '',
        repoPath:    repo.repoPath,
        repoName:    repo.repoName,
      ));
      conns.add(MindMapConnection(
        fromId: repo.id,
        toId:   treeId,
        style:  ConnectorStyle.dashed,
        color:  const Color(0x6034D399),
      ));
      // Diff card — connected from File Tree.
      if (!nodes.any((n) => n.id == diffId)) {
        nodes.add(DiffNodeData(
          id:          diffId,
          workspaceId: '',
          repoPath:    repo.repoPath,
          repoName:    repo.repoName,
        ));
        conns.add(MindMapConnection(
          fromId: treeId,
          toId:   diffId,
          style:  ConnectorStyle.dashed,
          color:  const Color(0x607C6BFF),
        ));
      }
    }
    // Also add one tree+diff per standalone workspace path that has no sessions.
    for (final ws in wsState.workspaces) {
      for (final path in ws.paths) {
        final treeId = 'tree:$path';
        final diffId  = 'diff:$path';
        if (nodes.any((n) => n.id == treeId)) continue;
        nodes.add(FileTreeNodeData(
          id:          treeId,
          workspaceId: ws.id,
          repoPath:    path,
          repoName:    p.basename(path),
        ));
        conns.add(MindMapConnection(
          fromId: 'ws:${ws.id}',
          toId:   treeId,
          style:  ConnectorStyle.dashed,
          color:  const Color(0x5034D399),
        ));
        if (!nodes.any((n) => n.id == diffId)) {
          nodes.add(DiffNodeData(
            id:          diffId,
            workspaceId: ws.id,
            repoPath:    path,
            repoName:    p.basename(path),
          ));
          conns.add(MindMapConnection(
            fromId: treeId,
            toId:   diffId,
            style:  ConnectorStyle.dashed,
            color:  const Color(0x507C6BFF),
          ));
        }
      }
    }

    // File editor node (when a file is open).
    if (editorState.isVisible && editorState.tabs.isNotEmpty) {
      final idx       = editorState.activeIndex.clamp(0, editorState.tabs.length - 1);
      final activeTab = editorState.tabs[idx];
      const editorId  = 'editor:active';
      nodes.add(EditorNodeData(
        id:       editorId,
        filePath: activeTab.filePath,
        content:  activeTab.content ?? '',
        language: _detectLanguage(activeTab.filePath),
      ));
    }

    // Run sessions — connect from the matching session/agent card.
    if (runState.sessions.isNotEmpty) {
      for (final runSess in runState.sessions) {
        final matchingWs = (wsState as WorkspaceLoaded? ?? wsState).workspaces
            .where((ws) => ws.paths.any((p2) => runSess.workspacePath.startsWith(p2)))
            .firstOrNull;
        final runId = 'run:${runSess.id}';
        nodes.add(RunNodeData(id: runId, session: runSess, workspaceId: matchingWs?.id ?? ''));
        // Prefer connecting from the session/agent card in the matching ws.
        final matchingAgent = nodes.whereType<AgentNodeData>()
            .where((a) => a.workspaceId == (matchingWs?.id ?? ''))
            .firstOrNull;
        conns.add(MindMapConnection(
          fromId: matchingAgent?.id ?? 'ws:${matchingWs?.id ?? ''}',
          toId:   runId,
          style:  runSess.status == RunStatus.running
              ? ConnectorStyle.animated
              : ConnectorStyle.solid,
          color:  runSess.status == RunStatus.running
              ? const Color(0xAA34D399)
              : const Color(0x8060A5FA),
        ));
      }
    }

    // ── Plugin-provided nodes ────────────────────────────────────────────────
    final pluginEntries = MindMapPluginRegistry.instance.collectNodes(context);
    for (final entry in pluginEntries) {
      if (nodes.any((n) => n.id == entry.data.id)) continue; // dedup
      nodes.add(entry.data);
      conns.addAll(entry.connections);
    }

    return (nodes: nodes, conns: conns);
  }

  String _detectLanguage(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.dart'   => 'Dart',
      '.ts'     => 'TypeScript',
      '.tsx'    => 'TSX',
      '.js'     => 'JavaScript',
      '.py'     => 'Python',
      '.go'     => 'Go',
      '.rs'     => 'Rust',
      '.yaml' || '.yml' => 'YAML',
      '.json'   => 'JSON',
      '.sql'    => 'SQL',
      '.md'     => 'Markdown',
      _         => ext.isNotEmpty ? ext.replaceFirst('.', '').toUpperCase() : 'TEXT',
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunCubit, RunState>(
      builder: (context, runState) {
        return BlocBuilder<WorkspaceCubit, WorkspaceState>(
          builder: (context, wsState) {
            return BlocBuilder<TerminalCubit, TerminalState>(
              builder: (context, termState) {
                return BlocBuilder<ReviewCubit, ReviewState>(
                  builder: (context, reviewState) {
                    return BlocBuilder<FileEditorCubit, FileEditorState>(
                      builder: (context, editorState) {
                        final (:nodes, :conns) =
                            _buildData(wsState, termState, reviewState, editorState, runState);

                        // Update cubit with new nodes (triggers layout if needed).
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final mm = context.read<MindMapCubit>();
                          mm.updateNodes(nodes, conns);
                          // If editor just became visible, unhide it and scroll to it.
                          if (editorState.isVisible && editorState.tabs.isNotEmpty) {
                            mm.showNode('editor:active');
                            _scrollToNode('editor:active', mm.state);
                          }
                        });

                        return _MindMapCanvas(
                          nodes:          nodes,
                          conns:          conns,
                          transformCtrl:  _transformCtrl,
                          dashAnimation:  _dashAnim,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Canvas ─────────────────────────────────────────────────────────────────

class _MindMapCanvas extends StatefulWidget {
  const _MindMapCanvas({
    required this.nodes,
    required this.conns,
    required this.transformCtrl,
    required this.dashAnimation,
  });
  final List<MindMapNodeData> nodes;
  final List<MindMapConnection> conns;
  final TransformationController transformCtrl;
  final Animation<double> dashAnimation;

  @override
  State<_MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends State<_MindMapCanvas> {
  bool _nodeDragging = false;

  // Large canvas with generous top/left padding so users can scroll in all
  // directions. boundaryMargin(infinity) on InteractiveViewer makes it infinite.
  static const _canvasW = 8000.0;
  static const _canvasH = 8000.0;

  // Column x positions mirrored from MindMapLayoutEngine, offset right for space.
  static const _colX = [2040.0, 2260.0, 2680.0, 2900.0, 3100.0, 3360.0, 3860.0, 4240.0, 4580.0];

  /// Returns a column-based fallback so nodes are never piled at (0,0).
  Offset _fallbackPos(MindMapNodeData node) {
    final col = node.columnIndex.clamp(0, _colX.length - 1);
    // Start at y=300 so users have room to scroll upward.
    return Offset(_colX[col], 2000.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0F14),
      child: Stack(
        children: [
          // ── Canvas (pan + pinch zoom) ────────────────────────────────
          InteractiveViewer(
            transformationController: widget.transformCtrl,
            // Infinite boundary — user can pan in any direction freely.
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 3.0,
            panEnabled: !_nodeDragging,
            scaleEnabled: true,
            constrained: false,
            child: SizedBox(
              width:  _canvasW,
              height: _canvasH,
              child: BlocBuilder<MindMapCubit, MindMapState>(
                builder: (context, mmState) {
                  final defaultSizeMap = {
                    for (final n in widget.nodes) n.id: n.defaultSize,
                  };
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Dot-grid background — RepaintBoundary so dots
                      // don't repaint when nodes move.
                      const Positioned.fill(
                        child: RepaintBoundary(child: _DotGrid()),
                      ),

                      // SVG connector layer (below nodes).
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: MindMapConnectorLayer(
                          connections:  widget.conns
                              .where((c) {
                                if (mmState.hidden.contains(c.fromId)) return false;
                                if (mmState.hidden.contains(c.toId))   return false;
                                final fromTag = widget.nodes
                                    .where((n) => n.id == c.fromId)
                                    .firstOrNull?.typeTag;
                                final toTag = widget.nodes
                                    .where((n) => n.id == c.toId)
                                    .firstOrNull?.typeTag;
                                if (fromTag != null && mmState.hiddenTypes.contains(fromTag)) return false;
                                if (toTag   != null && mmState.hiddenTypes.contains(toTag))   return false;
                                return true;
                              })
                              .toList(),
                          positions:    mmState.positions,
                          sizes:        mmState.sizes,
                          defaultSizes: defaultSizeMap,
                          dashAnimation: widget.dashAnimation,
                        ),
                        ),   // RepaintBoundary
                      ),

                      // Node cards (skip hidden and hidden-type).
                      for (final node in widget.nodes)
                        if (!mmState.hidden.contains(node.id) &&
                            !mmState.hiddenTypes.contains(node.typeTag))
                          MindMapNode(
                            key:              ValueKey(node.id),
                            id:               node.id,
                            defaultSize:      node.defaultSize,
                            minResizeSize:    NodeRegistry.minResizeSize(node),
                            fallbackPosition: _fallbackPos(node),
                            onClose:          () => context.read<MindMapCubit>().hideNode(node.id),
                            child:            NodeRegistry.build(node),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Toolbar overlay ───────────────────────────────────────────
          Positioned(
            top: 8, right: 8,
            child: _CanvasToolbar(
              transformCtrl: widget.transformCtrl,
            ),
          ),

          // ── Group sidebar (left) ──────────────────────────────────────
          Positioned(
            top: 8, left: 8, bottom: 8,
            child: _GroupSidebar(),
          ),
        ],
      ),
    );
  }
}

// ── Dot-grid background ────────────────────────────────────────────────────

class _DotGrid extends StatefulWidget {
  const _DotGrid();
  @override
  State<_DotGrid> createState() => _DotGridState();
}

class _DotGridState extends State<_DotGrid> {
  ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    _buildTile();
  }

  Future<void> _buildTile() async {
    const spacing = 28.0;
    const tileSize = spacing;
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    canvas.drawCircle(
      const Offset(tileSize / 2, tileSize / 2),
      0.9,
      Paint()..color = const Color(0x8C3A4560),
    );
    final picture = recorder.endRecording();
    final image   = await picture.toImage(tileSize.toInt(), tileSize.toInt());
    if (mounted) setState(() => _tile = image);
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    if (tile == null) return const SizedBox.expand();
    return CustomPaint(painter: _TiledDotPainter(tile));
  }
}

class _TiledDotPainter extends CustomPainter {
  const _TiledDotPainter(this.tile);
  final ui.Image tile;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = ui.ImageShader(
      tile,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_TiledDotPainter old) => old.tile != tile;
}

// ── Toolbar ────────────────────────────────────────────────────────────────

class _CanvasToolbar extends StatelessWidget {
  const _CanvasToolbar({required this.transformCtrl});
  final TransformationController transformCtrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToolBtn(
          icon: Icons.remove,
          tooltip: 'Zoom out',
          onTap: () => _zoom(context, 0.8),
        ),
        const SizedBox(width: 1),
        _ToolBtn(
          icon: Icons.filter_center_focus,
          tooltip: 'Fit / reset',
          onTap: () => transformCtrl.value = Matrix4.identity(),
        ),
        const SizedBox(width: 1),
        _ToolBtn(
          icon: Icons.add,
          tooltip: 'Zoom in',
          onTap: () => _zoom(context, 1.25),
        ),
        const SizedBox(width: 8),
        _ToolBtn(
          icon: Icons.refresh,
          tooltip: 'Reset layout',
          onTap: () => context.read<MindMapCubit>().resetLayout(),
        ),
        const SizedBox(width: 1),
        BlocBuilder<MindMapCubit, MindMapState>(
          buildWhen: (p, n) => p.hidden.length != n.hidden.length,
          builder: (context, state) {
            if (state.hidden.isEmpty) return const SizedBox.shrink();
            return Row(
              children: [
                _ToolBtn(
                  icon: Icons.visibility,
                  tooltip: 'Show all (${state.hidden.length} hidden)',
                  onTap: () => context.read<MindMapCubit>().showAllNodes(),
                ),
                const SizedBox(width: 1),
              ],
            );
          },
        ),
        const SizedBox(width: 1),
        _ViewsButton(),
        const SizedBox(width: 1),
      ],
    );
  }

  void _zoom(BuildContext context, double factor) {
    final m = transformCtrl.value.clone();
    m.scaleByDouble(factor, factor, 1.0, 1.0);
    transformCtrl.value = m;
  }
}

// ── Views popover button ───────────────────────────────────────────────────

class _ViewsButton extends StatelessWidget {
  const _ViewsButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MindMapCubit, MindMapState>(
      buildWhen: (p, n) =>
          p.savedViews.length != n.savedViews.length ||
          p.activeViewName != n.activeViewName,
      builder: (context, state) {
        final hasViews = state.savedViews.isNotEmpty;
        return Tooltip(
          message: 'Views',
          child: GestureDetector(
            onTap: () => _showViewsMenu(context, state),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: hasViews ? const Color(0xFF16192A) : const Color(0xFF12151C),
                border: Border.all(
                  color: hasViews ? const Color(0xFF7C6BFF) : const Color(0xFF2A3040),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.bookmarks_outlined, size: 13,
                      color: hasViews ? const Color(0xFF7C6BFF) : const Color(0xFF6B7898)),
                  const SizedBox(width: 4),
                  Text(
                    state.activeViewName ?? 'Views',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasViews ? const Color(0xFF9D8FFF) : const Color(0xFF6B7898),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showViewsMenu(BuildContext context, MindMapState state) {
    final cubit = context.read<MindMapCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: _ViewsSheet(initialState: state),
      ),
    );
  }
}

class _ViewsSheet extends StatefulWidget {
  const _ViewsSheet({required this.initialState});
  final MindMapState initialState;

  @override
  State<_ViewsSheet> createState() => _ViewsSheetState();
}

class _ViewsSheetState extends State<_ViewsSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(bottom: 60),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1218),
          border: Border.all(color: const Color(0xFF2A3040)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0xA0000000), blurRadius: 24)],
        ),
        child: BlocBuilder<MindMapCubit, MindMapState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmarks_outlined, size: 14, color: Color(0xFF7C6BFF)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Saved Views',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFE8E8FF))),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, size: 14, color: Color(0xFF6B7898)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF1E2330)),
                // Save current layout row.
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFE8E8FF)),
                          decoration: InputDecoration(
                            hintText: state.activeViewName ?? 'View name…',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF4A5680)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF2A3040)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF7C6BFF)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          final name = _ctrl.text.trim().isEmpty
                              ? (state.activeViewName ?? 'View ${state.savedViews.length + 1}')
                              : _ctrl.text.trim();
                          context.read<MindMapCubit>().saveView(name);
                          _ctrl.clear();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C6BFF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.savedViews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 6, 14, 14),
                    child: Text('No saved views yet',
                        style: TextStyle(fontSize: 11, color: Color(0xFF4A5680))),
                  )
                else ...[
                  const Divider(height: 1, color: Color(0xFF1E2330)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final entry in state.savedViews.entries)
                          _ViewRow(
                            snapshot: entry.value,
                            isActive: state.activeViewName == entry.key,
                            onLoad: () {
                              context.read<MindMapCubit>().loadView(entry.key);
                              Navigator.pop(context);
                            },
                            onDelete: () =>
                                context.read<MindMapCubit>().deleteView(entry.key),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  const _ViewRow({
    required this.snapshot,
    required this.isActive,
    required this.onLoad,
    required this.onDelete,
  });
  final MindMapViewSnapshot snapshot;
  final bool isActive;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onLoad,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.bookmark : Icons.bookmark_border,
              size: 13,
              color: isActive ? const Color(0xFF7C6BFF) : const Color(0xFF4A5680),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                snapshot.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? const Color(0xFFE8E8FF) : const Color(0xFF9BAACB),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '${snapshot.positions.length} nodes',
              style: const TextStyle(fontSize: 10, color: Color(0xFF4A5680)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: const Icon(Icons.delete_outline, size: 13, color: Color(0xFF4A5680)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF12151C),
            border: Border.all(color: const Color(0xFF2A3040)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFF6B7898)),
        ),
      ),
    );
  }
}

// ── Group sidebar ──────────────────────────────────────────────────────────

// ── Workspace-tree sidebar ─────────────────────────────────────────────────

class _GroupSidebar extends StatefulWidget {
  const _GroupSidebar();

  @override
  State<_GroupSidebar> createState() => _GroupSidebarState();
}

class _GroupSidebarState extends State<_GroupSidebar> {
  bool _collapsed = false;
  double _width = 220;
  static const _minWidth = 160.0;
  static const _maxWidth = 480.0;
  // Set of node ids whose children are expanded in the tree.
  final _expandedIds = <String>{};
  // Tracks which workspace ids have been auto-expanded on first appearance.
  final _autoExpandedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MindMapCubit, MindMapState>(
      builder: (context, mm) {
        if (_collapsed) {
          return _SidebarToggle(
            collapsed: true,
            onTap: () => setState(() => _collapsed = false),
          );
        }

        // ── Build adjacency from connections ──────────────────────────────
        final nodeById = <String, MindMapNodeData>{
          for (final n in mm.nodes) n.id: n,
        };
        final childMap = <String, List<String>>{};
        for (final c in mm.connections) {
          (childMap[c.fromId] ??= []).add(c.toId);
        }

        final workspaces = mm.nodes.whereType<WorkspaceNodeData>().toList();

        // Auto-expand workspaces only the first time they appear.
        for (final ws in workspaces) {
          if (_autoExpandedIds.add(ws.id)) {
            _expandedIds.add(ws.id);
          }
        }

        // Nodes reachable from any workspace (excluding workspace itself).
        final reachable = <String>{};
        for (final ws in workspaces) {
          _collectIds(ws.id, childMap, reachable);
        }
        // Orphans: not a workspace AND not reachable from any workspace.
        final orphans = mm.nodes
            .where((n) => n is! WorkspaceNodeData && !reachable.contains(n.id))
            .toList();

        final cubit = context.read<MindMapCubit>();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
          width: _width,
          decoration: BoxDecoration(
            color: const Color(0xEE0F1218),
            border: Border.all(color: const Color(0xFF1E2330)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 18)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, size: 14, color: Color(0xFF7C6BFF)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Show / Hide',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8E8FF),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (mm.hidden.isNotEmpty || mm.hiddenTypes.isNotEmpty)
                      InkWell(
                        onTap: () => cubit.showAllNodes(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Text('Show all',
                              style: TextStyle(fontSize: 9, color: Color(0xFF7C6BFF))),
                        ),
                      ),
                    InkWell(
                      onTap: () => setState(() => _collapsed = true),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.chevron_left, size: 14, color: Color(0xFF6B7898)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E2330)),
              // ── + Workspace action ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: _SidebarAction(
                  icon: Icons.create_new_folder_outlined,
                  label: '+ Workspace',
                  onTap: () => _createWorkspace(context),
                ),
              ),
              // ── Tree list ─────────────────────────────────────────────
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final ws in workspaces) ...[
                      _WsRow(
                        ws:             ws,
                        expanded:       _expandedIds.contains(ws.id),
                        hidden:         mm.hidden.contains(ws.id) ||
                                        mm.hiddenTypes.contains(ws.typeTag),
                        onToggleExpand: () => setState(() {
                          _expandedIds.contains(ws.id)
                              ? _expandedIds.remove(ws.id)
                              : _expandedIds.add(ws.id);
                        }),
                        onToggleHide: () => mm.hidden.contains(ws.id)
                            ? cubit.showNode(ws.id)
                            : cubit.hideNode(ws.id),
                      ),
                      if (_expandedIds.contains(ws.id))
                        ..._buildSubtree(
                          ws.id, childMap, nodeById, mm, cubit, depth: 1,
                          visited: {ws.id},
                        ),
                    ],
                    // Orphan nodes (editor, plugin cards not linked to any ws).
                    if (orphans.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 8, 8, 2),
                        child: Text(
                          'OTHER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A5680),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      for (final n in orphans)
                        _TreeRow(
                          node: n,
                          depth: 1,
                          hidden: mm.hidden.contains(n.id) ||
                              mm.hiddenTypes.contains(n.typeTag),
                          hasChildren: false,
                          expanded: false,
                          onToggle: () => mm.hidden.contains(n.id)
                              ? cubit.showNode(n.id)
                              : cubit.hideNode(n.id),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ), // Container
            // ── Resize handle (right edge) ──────────────────────────────
            Positioned(
              right: -4, top: 0, bottom: 0,
              width: 8,
              child: _SidebarResizeHandle(
                onDrag: (dx) => setState(() {
                  _width = (_width + dx).clamp(_minWidth, _maxWidth);
                }),
              ),
            ),
          ],
        ); // Stack
      },
    );
  }

  /// DFS through the connection graph, building [_TreeRow] widgets.
  List<Widget> _buildSubtree(
    String parentId,
    Map<String, List<String>> childMap,
    Map<String, MindMapNodeData> nodeById,
    MindMapState mm,
    MindMapCubit cubit, {
    required int depth,
    required Set<String> visited,
  }) {
    final widgets = <Widget>[];
    for (final childId in (childMap[parentId] ?? <String>[])) {
      if (!visited.add(childId)) continue;
      final node = nodeById[childId];
      if (node == null) continue;
      final isHidden = mm.hidden.contains(node.id) ||
          mm.hiddenTypes.contains(node.typeTag);
      final hasChildren = (childMap[node.id] ?? [])
          .any((id) => !visited.contains(id) && nodeById.containsKey(id));
      final isExpanded = _expandedIds.contains(node.id);

      widgets.add(_TreeRow(
        node: node,
        depth: depth,
        hidden: isHidden,
        hasChildren: hasChildren,
        expanded: isExpanded,
        onToggle: () => mm.hidden.contains(node.id)
            ? cubit.showNode(node.id)
            : cubit.hideNode(node.id),
        onToggleExpand: hasChildren
            ? () => setState(() => isExpanded
                ? _expandedIds.remove(node.id)
                : _expandedIds.add(node.id))
            : null,
      ));

      if (hasChildren && isExpanded) {
        widgets.addAll(_buildSubtree(
          node.id, childMap, nodeById, mm, cubit,
          depth: depth + 1,
          visited: {...visited},
        ));
      }
    }
    return widgets;
  }

  /// Collect all node ids reachable from [id] via [childMap].
  void _collectIds(String id, Map<String, List<String>> childMap, Set<String> out) {
    for (final child in (childMap[id] ?? <String>[])) {
      if (out.add(child)) _collectIds(child, childMap, out);
    }
  }
}

// ── Workspace header row ───────────────────────────────────────────────────

class _WsRow extends StatelessWidget {
  const _WsRow({
    required this.ws,
    required this.expanded,
    required this.hidden,
    required this.onToggleExpand,
    required this.onToggleHide,
  });
  final WorkspaceNodeData ws;
  final bool expanded;
  final bool hidden;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleHide;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggleExpand,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleHide,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  hidden ? Icons.visibility_off : Icons.visibility,
                  size: 13,
                  color: hidden ? const Color(0xFF4A5680) : const Color(0xFF7C6BFF),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.folder_copy_outlined,
              size: 13,
              color: hidden ? const Color(0xFF4A5680) : const Color(0xFF7C6BFF),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ws.workspace.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hidden ? const Color(0xFF4A5680) : const Color(0xFFE8E8FF),
                ),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 13,
              color: const Color(0xFF6B7898),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Child node row (with depth indent) ────────────────────────────────────

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.node,
    required this.depth,
    required this.hidden,
    required this.onToggle,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggleExpand,
  });
  final MindMapNodeData node;
  final int depth;
  final bool hidden;
  final VoidCallback onToggle;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggleExpand;

  ({String label, IconData icon, Color color}) get _meta => switch (node) {
    AgentNodeData    d => (
        label: d.session.displayName,
        icon:  Icons.terminal,
        color: d.isRunning ? const Color(0xFF34D399) : const Color(0xFF6B7898),
      ),
    RepoNodeData     d => (label: d.repoName, icon: Icons.source, color: const Color(0xFF9AA3BF)),
    BranchNodeData   d => (label: d.branch, icon: Icons.alt_route, color: const Color(0xFF60A5FA)),
    FilesNodeData    d => (
        label: p.basename(d.repoPath),
        icon:  Icons.insert_drive_file_outlined,
        color: const Color(0xFFFFAA33),
      ),
    FileTreeNodeData d => (
        label: d.repoName ?? 'Tree',
        icon:  Icons.account_tree_outlined,
        color: const Color(0xFF34D399),
      ),
    DiffNodeData     d => (
        label: d.repoName ?? 'Diff',
        icon:  Icons.compare_arrows_rounded,
        color: const Color(0xFF7C6BFF),
      ),
    EditorNodeData   d => (
        label: p.basename(d.filePath),
        icon:  Icons.code,
        color: const Color(0xFFFFCC44),
      ),
    RunNodeData      d => (
        label: d.session.config.name,
        icon:  Icons.play_circle_outline,
        color: d.session.status == RunStatus.running
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF6B7898),
      ),
    SessionNodeData  d => (label: d.session.displayName, icon: Icons.terminal, color: const Color(0xFF6B7898)),
    MindMapPluginNodeData _ => (label: node.id, icon: Icons.extension_outlined, color: const Color(0xFF9AA3BF)),
    WorkspaceNodeData  _   => (label: node.id, icon: Icons.folder_outlined, color: const Color(0xFF7C6BFF)),
  };

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    final indent = 10.0 + depth * 14.0;
    return InkWell(
      onTap: hasChildren ? onToggleExpand : onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent, 3, 8, 3),
        child: Row(
          children: [
            // Vertical tree line hint
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.only(right: 5),
              color: const Color(0xFF2A3040),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  hidden ? Icons.visibility_off : Icons.visibility,
                  size: 11,
                  color: hidden ? const Color(0xFF4A5680) : const Color(0x997C6BFF),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              m.icon,
              size: 11,
              color: hidden ? const Color(0xFF3D475E) : m.color,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                m.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: hidden ? const Color(0xFF4A5680) : const Color(0xFFB0B8D0),
                ),
              ),
            ),
            if (hasChildren) ...[
              const SizedBox(width: 2),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 11,
                color: const Color(0xFF6B7898),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ── Sidebar resize handle ──────────────────────────────────────────────────

class _SidebarResizeHandle extends StatefulWidget {
  const _SidebarResizeHandle({required this.onDrag});
  final ValueChanged<double> onDrag;

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onDrag(d.delta.dx),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width:  _hovered ? 3 : 1,
            height: double.infinity,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0xFF7C6BFF)
                  : const Color(0x40FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sidebar collapsed toggle ───────────────────────────────────────────────

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.onTap});
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show sidebar',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xEE0F1218),
            border: Border.all(color: const Color(0xFF1E2330)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF7C6BFF)),
        ),
      ),
    );
  }
}

// ── Sidebar actions ────────────────────────────────────────────────────────

Future<void> _createWorkspace(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF12151C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A3040)),
      ),
      title: const Text('New Workspace',
          style: TextStyle(color: Color(0xFFE8E8FF), fontSize: 14)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Color(0xFFE8E8FF)),
        decoration: const InputDecoration(
          hintText: 'Workspace name',
          hintStyle: TextStyle(color: Color(0xFF6B7898)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7898))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Pick folder →', style: TextStyle(color: Color(0xFF7C6BFF))),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  final folder = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Pick a folder for "$name"',
  );
  if (folder == null || !context.mounted) return;
  await context.read<WorkspaceCubit>().addWorkspace(folder, customName: name);
}

class _SidebarAction extends StatefulWidget {
  const _SidebarAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SidebarAction> createState() => _SidebarActionState();
}

class _SidebarActionState extends State<_SidebarAction> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF2A1E66) : const Color(0xFF1A1E2A),
            border: Border.all(color: _hovered ? const Color(0xFF7C6BFF) : const Color(0xFF2A3040)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 12, color: _hovered ? const Color(0xFFC084FC) : const Color(0xFF9AA3BF)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? const Color(0xFFE8E8FF) : const Color(0xFF9AA3BF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

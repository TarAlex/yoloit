import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/core/theme/theme_manager.dart';
import 'package:yoloit/features/collaboration/bloc/collaboration_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/runs/bloc/run_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_cubit.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/data/pty_service.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_cubit.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/ui/shell/main_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WorkspaceCubit()),
        BlocProvider(create: (_) => TerminalCubit()),
        BlocProvider(create: (_) => ReviewCubit()),
        BlocProvider(create: (_) => FileEditorCubit()),
        BlocProvider(create: (_) => RunCubit()),
        BlocProvider(create: (_) => MindMapCubit()),
        // CollaborationCubit must come after MindMapCubit so it can read it.
        BlocProvider(
          create: (ctx) => CollaborationCubit(
            mindMapCubit: ctx.read<MindMapCubit>(),
            onTerminalInput: PtyService.instance.write,
            reviewCubit: ctx.read<ReviewCubit>(),
            listDirectory: _listRepoDir,
            ensureNodesPopulated: () => _populateMindMap(
              ctx.read<MindMapCubit>(),
              ctx.read<WorkspaceCubit>().state,
              ctx.read<TerminalCubit>().state,
            ),
          ),
        ),
      ],
      child: ListenableBuilder(
        listenable: ThemeManager.instance,
        builder: (context, _) {
          return MaterialApp(
            title: 'yoloit',
            debugShowCheckedModeBanner: false,
            theme: ThemeManager.instance.theme,
            home: const _AutoHostShell(),
          );
        },
      ),
    );
  }

  /// Lists top-level directory entries for a repo path (depth 0 + depth 1).
  /// Used by CollaborationCubit to populate file-tree cards for ALL repos,
  /// not just the one active in ReviewCubit.
  static List<Map<String, dynamic>> _listRepoDir(String repoPath) {
    final dir = Directory(repoPath);
    if (!dir.existsSync()) return const [];
    final entries = <Map<String, dynamic>>[];
    // Root entry
    entries.add({
      'name': p.basename(repoPath),
      'path': repoPath,
      'isDir': true,
      'depth': 0,
      'isExpanded': true,
    });
    // Children (depth 1, sorted: dirs first, then files)
    try {
      final children = dir.listSync()
        ..sort((a, b) {
          final aDir = a is Directory;
          final bDir = b is Directory;
          if (aDir != bDir) return aDir ? -1 : 1;
          return p.basename(a.path).compareTo(p.basename(b.path));
        });
      for (final child in children.take(50)) {
        final name = p.basename(child.path);
        if (name.startsWith('.') && name != '.github') continue;
        entries.add({
          'name': name,
          'path': child.path,
          'isDir': child is Directory,
          'depth': 1,
          'isExpanded': false,
        });
      }
    } catch (_) {}
    return entries;
  }

  /// Populates [mindMapCubit] with nodes derived from workspace and terminal
  /// state so that browser guests see a meaningful canvas even when the user
  /// has not yet opened the Map View in the macOS app.
  static Future<void> _populateMindMap(
    MindMapCubit mindMapCubit,
    WorkspaceState wsState,
    TerminalState termState,
  ) async {
    // Skip only when both positions and nodes are already populated.
    if (mindMapCubit.state.positions.isNotEmpty &&
        mindMapCubit.state.nodes.isNotEmpty) return;
    if (wsState is! WorkspaceLoaded) return;

    final nodes = <MindMapNodeData>[];
    final conns = <MindMapConnection>[];

    for (final ws in wsState.workspaces) {
      final wsNodeId = 'ws:${ws.id}';
      nodes.add(WorkspaceNodeData(id: wsNodeId, workspace: ws));

      final sessions = termState is TerminalLoaded
          ? termState.allSessions.where((s) {
              if (s.workspaceId != null) return s.workspaceId == ws.id;
              return ws.paths.any((p2) => s.workspacePath.startsWith(p2));
            }).toList()
          : <AgentSession>[];

      for (final session in sessions) {
        final agentId = 'agent:${session.id}';
        nodes.add(AgentNodeData(
          id:              agentId,
          session:         session,
          workspaceId:     ws.id,
          workspacePaths:  ws.paths,
          workspaceBranch: ws.gitBranch,
        ));
        final isLive = session.status == AgentStatus.live;
        conns.add(MindMapConnection(
          fromId: wsNodeId, toId: agentId,
          style:  isLive ? ConnectorStyle.animated : ConnectorStyle.solid,
          color:  (isLive ? const Color(0xFF34D399) : const Color(0xFF60A5FA)).withAlpha(100),
        ));

        final wt = session.worktreeContexts;
        final repoPaths = <String, String>{};
        if (wt != null && wt.isNotEmpty) {
          repoPaths.addAll(wt);
        } else {
          for (final rp in ws.paths) {
            repoPaths[rp] = ws.gitBranch ?? 'main';
          }
        }

        for (final entry in repoPaths.entries) {
          final repoPath     = entry.key;
          final branchRef    = entry.value;
          final repoName     = p.basename(repoPath);
          final repoNodeId   = 'repo:${ws.id}:$repoPath';
          final branchNodeId = 'branch:${ws.id}:$repoPath';

          if (!nodes.any((n) => n.id == repoNodeId)) {
            nodes.add(RepoNodeData(
              id: repoNodeId, sessionId: session.id,
              repoPath: repoPath, repoName: repoName,
              branch: p.basename(branchRef),
            ));
          }
          conns.add(MindMapConnection(
            fromId: agentId, toId: repoNodeId,
            style: ConnectorStyle.solid, color: const Color(0x59C084FC),
          ));
          if (!nodes.any((n) => n.id == branchNodeId)) {
            nodes.add(BranchNodeData(
              id: branchNodeId, repoId: repoNodeId,
              repoName: repoName, branch: p.basename(branchRef),
              commitHash: '',
            ));
          }
          conns.add(MindMapConnection(
            fromId: repoNodeId, toId: branchNodeId,
            style: ConnectorStyle.dashed, color: const Color(0x597C6BFF),
          ));
        }
      }
    }

    // Orphan sessions not matched to any workspace.
    if (termState is TerminalLoaded) {
      final existing = nodes.whereType<AgentNodeData>().map((a) => a.session.id).toSet();
      for (final session in termState.allSessions) {
        if (existing.contains(session.id)) continue;
        final agentId   = 'agent:${session.id}';
        final matchedWs = wsState.workspaces.where((w) =>
          w.id == session.workspaceId ||
          w.paths.any((p2) => session.workspacePath.startsWith(p2))).firstOrNull;
        nodes.add(AgentNodeData(
          id: agentId, session: session,
          workspaceId:     session.workspaceId ?? '',
          workspacePaths:  matchedWs?.paths ?? const [],
          workspaceBranch: matchedWs?.gitBranch,
        ));
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
            fromId: agentId, toId: repoNodeId,
            style: ConnectorStyle.solid, color: const Color(0x59C084FC),
          ));
          if (!nodes.any((n) => n.id == brNodeId)) {
            nodes.add(BranchNodeData(
              id: brNodeId, repoId: repoNodeId,
              repoName: repoName, branch: p.basename(branchRef),
              commitHash: '',
            ));
          }
          conns.add(MindMapConnection(
            fromId: repoNodeId, toId: brNodeId,
            style: ConnectorStyle.dashed, color: const Color(0x597C6BFF),
          ));
        }
      }
    }

    // FileTree + Diff cards per repo.
    for (final repo in nodes.whereType<RepoNodeData>().toList()) {
      final treeId = 'tree:${repo.repoPath}';
      final diffId = 'diff:${repo.repoPath}';
      if (nodes.any((n) => n.id == treeId)) continue;
      nodes.add(FileTreeNodeData(
        id: treeId, workspaceId: '', repoPath: repo.repoPath, repoName: repo.repoName,
      ));
      conns.add(MindMapConnection(
        fromId: repo.id, toId: treeId,
        style: ConnectorStyle.dashed, color: const Color(0x6034D399),
      ));
      if (!nodes.any((n) => n.id == diffId)) {
        nodes.add(DiffNodeData(
          id: diffId, workspaceId: '', repoPath: repo.repoPath, repoName: repo.repoName,
        ));
        conns.add(MindMapConnection(
          fromId: treeId, toId: diffId,
          style: ConnectorStyle.dashed, color: const Color(0x607C6BFF),
        ));
      }
    }

    if (nodes.isEmpty) return;
    mindMapCubit.updateNodes(nodes, conns);
    await Future<void>.delayed(Duration.zero);
  }
}

/// Wraps [MainShell] and auto-starts the collaboration server on the first
/// frame so the host is always reachable via browser without a manual tap.
class _AutoHostShell extends StatefulWidget {
  const _AutoHostShell();

  @override
  State<_AutoHostShell> createState() => _AutoHostShellState();
}

class _AutoHostShellState extends State<_AutoHostShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CollaborationCubit>().startHosting();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const MainShell();
}

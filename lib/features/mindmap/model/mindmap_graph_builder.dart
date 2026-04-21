import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/runs/bloc/run_state.dart';
import 'package:yoloit/features/runs/models/run_session.dart';
import 'package:yoloit/features/terminal/bloc/terminal_state.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';

({List<MindMapNodeData> nodes, List<MindMapConnection> conns})
buildMindMapGraph({
  required WorkspaceState wsState,
  required TerminalState termState,
  required ReviewState reviewState,
  required FileEditorState editorState,
  required RunState runState,
}) {
  final nodes = <MindMapNodeData>[];
  final conns = <MindMapConnection>[];

  if (wsState is! WorkspaceLoaded) return (nodes: nodes, conns: conns);

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
      final agentNodeId = 'agent:${session.id}';
      nodes.add(
        AgentNodeData(
          id: agentNodeId,
          session: session,
          workspaceId: ws.id,
          workspacePaths: ws.paths,
          workspaceBranch: ws.gitBranch,
        ),
      );

      final isLive = session.status == AgentStatus.live;
      final agentConnStyle = isLive
          ? ConnectorStyle.animated
          : ConnectorStyle.solid;
      final agentColor = isLive
          ? const Color(0xFF34D399)
          : const Color(0xFF60A5FA);

      conns.add(
        MindMapConnection(
          fromId: wsNodeId,
          toId: agentNodeId,
          style: agentConnStyle,
          color: agentColor.withAlpha(100),
        ),
      );

      final wt = session.worktreeContexts;
      final repoPaths = <String, String>{};
      if (wt != null && wt.isNotEmpty) {
        repoPaths.addAll(wt);
      } else {
        for (final repoPath in ws.paths) {
          repoPaths[repoPath] = ws.gitBranch ?? 'main';
        }
      }

      for (final entry in repoPaths.entries) {
        final repoPath = entry.key;
        final branchRef = entry.value;
        final repoName = p.basename(repoPath);
        final repoNodeId = 'repo:${ws.id}:$repoPath';
        final branchNodeId = 'branch:${ws.id}:$repoPath';

        if (!nodes.any((node) => node.id == repoNodeId)) {
          nodes.add(
            RepoNodeData(
              id: repoNodeId,
              sessionId: session.id,
              repoPath: repoPath,
              repoName: repoName,
              branch: p.basename(branchRef),
            ),
          );
        }
        conns.add(
          MindMapConnection(
            fromId: agentNodeId,
            toId: repoNodeId,
            style: ConnectorStyle.solid,
            color: const Color(0x59C084FC),
          ),
        );

        if (!nodes.any((node) => node.id == branchNodeId)) {
          nodes.add(
            BranchNodeData(
              id: branchNodeId,
              repoId: repoNodeId,
              repoName: repoName,
              branch: p.basename(branchRef),
              commitHash: '',
            ),
          );
        }
        conns.add(
          MindMapConnection(
            fromId: repoNodeId,
            toId: branchNodeId,
            style: ConnectorStyle.dashed,
            color: const Color(0x597C6BFF),
          ),
        );
      }
    }
  }

  if (termState is TerminalLoaded) {
    final existingAgents = nodes
        .whereType<AgentNodeData>()
        .map((agent) => agent.session.id)
        .toSet();
    for (final session in termState.allSessions) {
      if (existingAgents.contains(session.id)) continue;
      final agentNodeId = 'agent:${session.id}';
      final matchedWs = wsState.workspaces
          .where(
            (workspace) =>
                workspace.id == session.workspaceId ||
                workspace.paths.any(
                  (repoPath) => session.workspacePath.startsWith(repoPath),
                ),
          )
          .firstOrNull;
      nodes.add(
        AgentNodeData(
          id: agentNodeId,
          session: session,
          workspaceId: session.workspaceId ?? '',
          workspacePaths: matchedWs?.paths ?? const [],
          workspaceBranch: matchedWs?.gitBranch,
        ),
      );

      final wt = session.worktreeContexts?.isNotEmpty == true
          ? session.worktreeContexts!
          : (matchedWs != null && matchedWs.paths.isNotEmpty
                ? {
                    for (final repoPath in matchedWs.paths)
                      repoPath: matchedWs.gitBranch ?? 'main',
                  }
                : {session.workspacePath: 'main'});
      for (final entry in wt.entries) {
        final repoPath = entry.key;
        final branchRef = entry.value;
        final repoName = p.basename(repoPath);
        final repoNodeId = 'repo:orphan:$repoPath';
        final branchNodeId = 'branch:orphan:$repoPath';
        if (!nodes.any((node) => node.id == repoNodeId)) {
          nodes.add(
            RepoNodeData(
              id: repoNodeId,
              sessionId: session.id,
              repoPath: repoPath,
              repoName: repoName,
              branch: p.basename(branchRef),
            ),
          );
        }
        conns.add(
          MindMapConnection(
            fromId: agentNodeId,
            toId: repoNodeId,
            style: ConnectorStyle.solid,
            color: const Color(0x59C084FC),
          ),
        );
        if (!nodes.any((node) => node.id == branchNodeId)) {
          nodes.add(
            BranchNodeData(
              id: branchNodeId,
              repoId: repoNodeId,
              repoName: repoName,
              branch: p.basename(branchRef),
              commitHash: '',
            ),
          );
        }
        conns.add(
          MindMapConnection(
            fromId: repoNodeId,
            toId: branchNodeId,
            style: ConnectorStyle.dashed,
            color: const Color(0x597C6BFF),
          ),
        );
      }
    }
  }

  if (reviewState is ReviewLoaded && reviewState.changedFiles.isNotEmpty) {
    final groupedByRepo = <String, List<dynamic>>{};
    for (final file in reviewState.changedFiles) {
      final repoPath = file.repoPath ?? 'unknown';
      groupedByRepo.putIfAbsent(repoPath, () => []).add(file);
    }
    for (final entry in groupedByRepo.entries) {
      final filesId = 'files:${entry.key}';
      nodes.add(
        FilesNodeData(
          id: filesId,
          sessionId: '',
          repoPath: entry.key,
          changedFiles: entry.value.cast(),
        ),
      );
      final branchNode = nodes
          .whereType<BranchNodeData>()
          .where((branch) => branch.repoName == p.basename(entry.key))
          .firstOrNull;
      if (branchNode != null) {
        conns.add(
          MindMapConnection(
            fromId: branchNode.id,
            toId: filesId,
            style: ConnectorStyle.dashed,
            color: const Color(0x406B7898),
          ),
        );
      }
    }
  }

  final repoNodes = nodes.whereType<RepoNodeData>().toList();
  for (final repo in repoNodes) {
    final treeId = 'tree:${repo.repoPath}';
    final diffId = 'diff:${repo.repoPath}';
    if (nodes.any((node) => node.id == treeId)) continue;
    nodes.add(
      FileTreeNodeData(
        id: treeId,
        workspaceId: '',
        repoPath: repo.repoPath,
        repoName: repo.repoName,
      ),
    );
    conns.add(
      MindMapConnection(
        fromId: repo.id,
        toId: treeId,
        style: ConnectorStyle.dashed,
        color: const Color(0x6034D399),
      ),
    );
    if (!nodes.any((node) => node.id == diffId)) {
      nodes.add(
        DiffNodeData(
          id: diffId,
          workspaceId: '',
          repoPath: repo.repoPath,
          repoName: repo.repoName,
        ),
      );
      conns.add(
        MindMapConnection(
          fromId: treeId,
          toId: diffId,
          style: ConnectorStyle.dashed,
          color: const Color(0x607C6BFF),
        ),
      );
    }
  }

  for (final ws in wsState.workspaces) {
    for (final path in ws.paths) {
      final treeId = 'tree:$path';
      final diffId = 'diff:$path';
      if (nodes.any((node) => node.id == treeId)) continue;
      nodes.add(
        FileTreeNodeData(
          id: treeId,
          workspaceId: ws.id,
          repoPath: path,
          repoName: p.basename(path),
        ),
      );
      conns.add(
        MindMapConnection(
          fromId: 'ws:${ws.id}',
          toId: treeId,
          style: ConnectorStyle.dashed,
          color: const Color(0x5034D399),
        ),
      );
      if (!nodes.any((node) => node.id == diffId)) {
        nodes.add(
          DiffNodeData(
            id: diffId,
            workspaceId: ws.id,
            repoPath: path,
            repoName: p.basename(path),
          ),
        );
        conns.add(
          MindMapConnection(
            fromId: treeId,
            toId: diffId,
            style: ConnectorStyle.dashed,
            color: const Color(0x507C6BFF),
          ),
        );
      }
    }
  }

  if (editorState.isVisible && editorState.tabs.isNotEmpty) {
    final idx = editorState.activeIndex.clamp(0, editorState.tabs.length - 1);
    final activeTab = editorState.tabs[idx];
    const editorId = 'editor:active';
    nodes.add(
      EditorNodeData(
        id: editorId,
        filePath: activeTab.filePath,
        content: activeTab.content ?? '',
        language: _detectLanguage(activeTab.filePath),
      ),
    );
    final filePath = activeTab.filePath;
    final matchingTree = nodes
        .whereType<FileTreeNodeData>()
        .where(
          (tree) =>
              tree.repoPath != null && filePath.startsWith(tree.repoPath!),
        )
        .fold<FileTreeNodeData?>(
          null,
          (best, tree) =>
              best == null ||
                  (tree.repoPath?.length ?? 0) > (best.repoPath?.length ?? 0)
              ? tree
              : best,
        );
    if (matchingTree != null) {
      conns.add(
        MindMapConnection(
          fromId: matchingTree.id,
          toId: editorId,
          style: ConnectorStyle.dashed,
          color: const Color(0x7060A5FA),
        ),
      );
    }
  }

  if (runState.sessions.isNotEmpty) {
    for (final runSession in runState.sessions) {
      final matchingWs = wsState.workspaces
          .where(
            (workspace) => workspace.paths.any(
              (repoPath) => runSession.workspacePath.startsWith(repoPath),
            ),
          )
          .firstOrNull;
      final runId = 'run:${runSession.id}';
      nodes.add(
        RunNodeData(
          id: runId,
          session: runSession,
          workspaceId: matchingWs?.id ?? '',
        ),
      );
      final matchingAgent = nodes
          .whereType<AgentNodeData>()
          .where((agent) => agent.workspaceId == (matchingWs?.id ?? ''))
          .firstOrNull;
      conns.add(
        MindMapConnection(
          fromId: matchingAgent?.id ?? 'ws:${matchingWs?.id ?? ''}',
          toId: runId,
          style: runSession.status == RunStatus.running
              ? ConnectorStyle.animated
              : ConnectorStyle.solid,
          color: runSession.status == RunStatus.running
              ? const Color(0xAA34D399)
              : const Color(0x8060A5FA),
        ),
      );
    }
  }

  return (nodes: nodes, conns: conns);
}

String _detectLanguage(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.dart' => 'Dart',
    '.ts' => 'TypeScript',
    '.tsx' => 'TSX',
    '.js' => 'JavaScript',
    '.py' => 'Python',
    '.go' => 'Go',
    '.rs' => 'Rust',
    '.yaml' || '.yml' => 'YAML',
    '.json' => 'JSON',
    '.sql' => 'SQL',
    '.md' => 'Markdown',
    _ => ext.isNotEmpty ? ext.replaceFirst('.', '').toUpperCase() : 'TEXT',
  };
}

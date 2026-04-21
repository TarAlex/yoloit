import 'package:path/path.dart' as p;

import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';

AgentCardProps buildAgentCardProps(AgentNodeData data) {
  final session = data.session;
  final rawWorktrees = session.worktreeContexts ?? const <String, String>{};
  final worktrees = rawWorktrees.isNotEmpty
      ? rawWorktrees
      : data.workspacePaths.isNotEmpty
      ? {
          for (final repoPath in data.workspacePaths)
            repoPath: data.workspaceBranch ?? 'main',
        }
      : {session.workspacePath: 'main'};

  return AgentCardProps(
    name: session.displayName,
    status: session.status.name,
    isRunning: data.isRunning,
    typeName: session.type.displayName,
    lastLines: session.lastLines(80),
    repos: worktrees.entries
        .map(
          (entry) => RepoBranchInfo(
            repo: p.basename(entry.key),
            branch: p.basename(entry.value),
          ),
        )
        .toList(),
    isIdle: session.status == AgentStatus.idle && session.sessionId == null,
  );
}

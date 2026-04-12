import 'dart:io';

import 'package:path/path.dart' as p;

class AgentWorkspaceDirService {
  AgentWorkspaceDirService._();
  static final instance = AgentWorkspaceDirService._();

  static String _baseDir() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.config', 'yoloit', 'workspaces');
  }

  String dirForAgent(String workspaceId, String agentId) =>
      p.join(_baseDir(), workspaceId, 'agents', agentId);

  /// Creates the agent directory with symlinks for each repo → selected worktree path.
  /// [worktreeContexts] maps repoPath → selectedWorktreePath.
  /// Returns the agent directory path.
  Future<String> createAgentDir(
    String workspaceId,
    String agentId,
    Map<String, String> worktreeContexts,
  ) async {
    final dir = Directory(dirForAgent(workspaceId, agentId));
    await dir.create(recursive: true);

    for (final entry in worktreeContexts.entries) {
      final repoPath = entry.key;
      final worktreePath = entry.value;
      final linkName = p.basename(repoPath);
      final link = Link(p.join(dir.path, linkName));
      if (await link.exists()) await link.delete();
      await link.create(worktreePath);
    }

    return dir.path;
  }

  Future<void> deleteAgentDir(String workspaceId, String agentId) async {
    final dir = Directory(dirForAgent(workspaceId, agentId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

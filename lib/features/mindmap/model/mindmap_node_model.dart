import 'package:flutter/material.dart';
import 'package:yoloit/features/review/models/review_models.dart';
import 'package:yoloit/features/runs/models/run_session.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

/// Base sealed class for all mind-map node types.
/// To add a new card type:
///  1. Add a new subclass here.
///  2. Register it in NodeRegistry.build(data).
///  Done — layout and drag/resize work automatically.
sealed class MindMapNodeData {
  const MindMapNodeData({required this.id});
  final String id;

  /// Suggested default size for auto-layout; actual size may grow with content.
  Size get defaultSize;

  /// Column index used by the layout engine (0 = leftmost).
  int get columnIndex;

  /// Short group tag for sidebar filtering (e.g. 'ws','agent','repo',...).
  String get typeTag;
}

// ── Workspace ──────────────────────────────────────────────────────────────

class WorkspaceNodeData extends MindMapNodeData {
  const WorkspaceNodeData({required super.id, required this.workspace});
  final Workspace workspace;

  @override
  Size get defaultSize => const Size(220, 148);

  @override
  int get columnIndex => 0;

  @override
  String get typeTag => 'ws';
}

// ── Session ────────────────────────────────────────────────────────────────

class SessionNodeData extends MindMapNodeData {
  const SessionNodeData({
    required super.id,
    required this.workspaceId,
    required this.session,
  });
  final String workspaceId;
  final AgentSession session;

  @override
  Size get defaultSize => const Size(220, 118); // 90 content + 28 handles

  @override
  int get columnIndex => 1;

  @override
  String get typeTag => 'session';
}

// ── Repo ───────────────────────────────────────────────────────────────────

class RepoNodeData extends MindMapNodeData {
  const RepoNodeData({
    required super.id,
    required this.sessionId,
    required this.repoPath,
    required this.repoName,
    required this.branch,
  });
  final String sessionId;
  final String repoPath;
  final String repoName;
  final String branch;

  @override
  Size get defaultSize => const Size(180, 98); // 70 content + 28 handles

  @override
  int get columnIndex => 2;

  @override
  String get typeTag => 'repo';
}

// ── Branch ─────────────────────────────────────────────────────────────────

class BranchNodeData extends MindMapNodeData {
  const BranchNodeData({
    required super.id,
    required this.repoId,
    required this.repoName,
    required this.branch,
    required this.commitHash,
  });
  final String repoId;
  final String repoName;
  final String branch;
  final String commitHash;

  @override
  Size get defaultSize => const Size(170, 93); // 65 content + 28 handles

  @override
  int get columnIndex => 3;

  @override
  String get typeTag => 'branch';
}

// ── Agent (terminal) ───────────────────────────────────────────────────────
// NOTE: sessions are 1:1 with terminals in our data model, so we merge them
// into this single "session+terminal" card — placed in the Sessions column.

class AgentNodeData extends MindMapNodeData {
  const AgentNodeData({
    required super.id,
    required this.session,
    required this.workspaceId,
    this.workspacePaths = const [],
    this.workspaceBranch,
  });
  final AgentSession session;
  final String workspaceId;
  /// Fallback repo paths from the parent workspace (used when session has no worktreeContexts).
  final List<String> workspacePaths;
  final String? workspaceBranch;

  AgentStatus get status => session.status;
  bool get isRunning => status == AgentStatus.live;

  @override
  Size get defaultSize => const Size(360, 280); // terminal needs room

  @override
  int get columnIndex => 1; // merged into Sessions column

  @override
  String get typeTag => 'agent';
}

// ── Files Changed ──────────────────────────────────────────────────────────

class FilesNodeData extends MindMapNodeData {
  const FilesNodeData({
    required super.id,
    required this.sessionId,
    required this.repoPath,
    required this.changedFiles,
  });
  final String sessionId;
  final String repoPath;
  final List<FileChange> changedFiles;

  @override
  Size get defaultSize => const Size(220, 188);

  @override
  int get columnIndex => 4; // shifted left since sessions+terminals merged

  @override
  String get typeTag => 'files';
}

// ── File Tree (file browser only) ──────────────────────────────────────────

class FileTreeNodeData extends MindMapNodeData {
  const FileTreeNodeData({
    required super.id,
    required this.workspaceId,
    this.repoPath,
    this.repoName,
  });
  final String workspaceId;
  final String? repoPath;
  final String? repoName;

  @override
  Size get defaultSize => const Size(300, 360);

  @override
  int get columnIndex => 7;

  @override
  String get typeTag => 'tree';
}

// ── Diff / Git Changes (diff viewer only) ──────────────────────────────────

class DiffNodeData extends MindMapNodeData {
  const DiffNodeData({
    required super.id,
    required this.workspaceId,
    this.repoPath,
    this.repoName,
  });
  final String workspaceId;
  final String? repoPath;
  final String? repoName;

  @override
  Size get defaultSize => const Size(340, 380);

  @override
  int get columnIndex => 8;

  @override
  String get typeTag => 'diff';
}

// ── File Editor ────────────────────────────────────────────────────────────

class EditorNodeData extends MindMapNodeData {
  const EditorNodeData({
    required super.id,
    required this.filePath,
    required this.content,
    required this.language,
  });
  final String filePath;
  final String content;
  final String language;

  @override
  Size get defaultSize => const Size(460, 348);

  @override
  int get columnIndex => 5;

  @override
  String get typeTag => 'editor';
}

// ── Standalone file panel (own FileEditorCubit) ───────────────────────────

/// A file opened as an independent canvas card via "Open in Panel".
/// Unlike [EditorNodeData] (which binds to the shared FileEditorCubit),
/// this node carries its own file path and spawns a private cubit so
/// multiple panels can coexist.
class FilePanelNodeData extends MindMapNodeData {
  const FilePanelNodeData({
    required super.id,
    required this.filePath,
  });
  final String filePath;

  @override
  Size get defaultSize => const Size(460, 348);

  @override
  int get columnIndex => 5;

  @override
  String get typeTag => 'panel';
}

// ── Run Session ────────────────────────────────────────────────────────────

class RunNodeData extends MindMapNodeData {
  const RunNodeData({
    required super.id,
    required this.session,
    required this.workspaceId,
  });
  final RunSession session;
  final String workspaceId;

  @override
  Size get defaultSize => const Size(320, 240);

  @override
  int get columnIndex => 6; // rightmost — attached from session with curve

  @override
  String get typeTag => 'run';
}

// ── Plugin node (external / third-party cards) ─────────────────────────────
// All third-party cards are carried through this single sealed subclass.
// The registry routes rendering to the right [MindMapCardPlugin] via [pluginId].

class MindMapPluginNodeData extends MindMapNodeData {
  const MindMapPluginNodeData({
    required super.id,
    required this.pluginId,
    required int columnIndex,
    required String typeTag,
    required Size defaultSize,
    this.payload = const {},
  })  : _columnIndex = columnIndex,
        _typeTag     = typeTag,
        _defaultSize = defaultSize;

  /// Reverse-domain plugin identifier — must match [MindMapCardPlugin.pluginId].
  final String pluginId;

  /// Arbitrary structured data the plugin uses to render its card.
  final Map<String, dynamic> payload;

  final int    _columnIndex;
  final String _typeTag;
  final Size   _defaultSize;

  @override int    get columnIndex => _columnIndex;
  @override String get typeTag     => _typeTag;
  @override Size   get defaultSize => _defaultSize;
}

enum ConnectorStyle {
  solid,        // solid curve
  dashed,       // static dashes
  animated,     // flowing animated dashes (for running agents)
}

class MindMapConnection {
  const MindMapConnection({
    required this.fromId,
    required this.toId,
    required this.style,
    required this.color,
  });
  final String fromId;
  final String toId;
  final ConnectorStyle style;
  final Color color;
}

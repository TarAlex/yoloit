import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/agent_node.dart';
import 'package:yoloit/features/mindmap/nodes/editor_node.dart';
import 'package:yoloit/features/mindmap/nodes/file_tree_node.dart';
import 'package:yoloit/features/mindmap/nodes/files_node.dart';
import 'package:yoloit/features/mindmap/nodes/repo_branch_node.dart';
import 'package:yoloit/features/mindmap/nodes/run_node.dart';
import 'package:yoloit/features/mindmap/nodes/session_node.dart';
import 'package:yoloit/features/mindmap/nodes/workspace_node.dart';

/// Central factory that maps [MindMapNodeData] to its visual widget.
///
/// To add a new card type in the future:
///   1. Add a new subclass to [MindMapNodeData].
///   2. Add a new `case` here.
///   Done — layout, drag, and resize handle the rest automatically.
abstract final class NodeRegistry {
  static Widget build(MindMapNodeData data) => switch (data) {
    WorkspaceNodeData d => WorkspaceNode(data: d),
    SessionNodeData   d => SessionNode(data: d),
    RepoNodeData      d => RepoNode(data: d),
    BranchNodeData    d => BranchNode(data: d),
    AgentNodeData     d => AgentNode(data: d),
    FilesNodeData     d => FilesNode(data: d),
    FileTreeNodeData  d => FileTreeNode(data: d),
    EditorNodeData    d => EditorNode(data: d),
    RunNodeData       d => RunNode(data: d),
  };

  /// Whether a node should have a user-resizable handle.
  static bool isResizable(MindMapNodeData data) => switch (data) {
    AgentNodeData()    => true,
    FilesNodeData()    => true,
    FileTreeNodeData() => true,
    EditorNodeData()   => true,
    _                  => false,
  };

  /// Minimum resize size — must be larger than drag handle + resize handle (28px).
  static Size minResizeSize(MindMapNodeData data) => switch (data) {
    AgentNodeData()     => const Size(240, 140),
    FilesNodeData()     => const Size(180, 100),
    FileTreeNodeData()  => const Size(240, 200),
    EditorNodeData()    => const Size(280, 160),
    RunNodeData()       => const Size(280, 180),
    WorkspaceNodeData() => const Size(160, 76),
    SessionNodeData()   => const Size(180, 76),
    _                   => const Size(140, 76),
  };
}

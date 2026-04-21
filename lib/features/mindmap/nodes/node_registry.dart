import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/agent_node.dart';
import 'package:yoloit/features/mindmap/nodes/editor_node.dart';
import 'package:yoloit/features/mindmap/nodes/diff_node.dart';
import 'package:yoloit/features/mindmap/nodes/file_panel_node.dart';
import 'package:yoloit/features/mindmap/nodes/file_tree_node.dart';
import 'package:yoloit/features/mindmap/nodes/files_node.dart';
import 'package:yoloit/features/mindmap/nodes/repo_branch_node.dart';
import 'package:yoloit/features/mindmap/nodes/run_node.dart';
import 'package:yoloit/features/mindmap/nodes/session_node.dart';
import 'package:yoloit/features/mindmap/nodes/workspace_node.dart';
import 'package:yoloit/features/mindmap/plugin/mindmap_plugin_registry.dart';

/// Central factory that maps [MindMapNodeData] to its visual widget.
///
/// **Built-in types** are handled via the exhaustive switch below.
/// **Plugin types** ([MindMapPluginNodeData]) are delegated to
/// [MindMapPluginRegistry] which routes to the correct [MindMapCardPlugin].
///
/// To add a new BUILT-IN card type:
///   1. Add a new subclass to [MindMapNodeData] (same file — sealed).
///   2. Add a new `case` in each method below.
///   Done — layout, drag, and resize handle the rest automatically.
///
/// To add a PLUGIN card type (external / third-party):
///   1. Implement [MindMapCardPlugin].
///   2. Call [MindMapPluginRegistry.instance.register(myPlugin)] at startup.
///   Done — no changes to this file needed.
abstract final class NodeRegistry {
  static Widget build(MindMapNodeData data) => switch (data) {
    WorkspaceNodeData    d => WorkspaceNode(data: d),
    SessionNodeData      d => SessionNode(data: d),
    RepoNodeData         d => RepoNode(data: d),
    BranchNodeData       d => BranchNode(data: d),
    AgentNodeData        d => AgentNode(data: d),
    FilesNodeData        d => FilesNode(data: d),
    FileTreeNodeData     d => FileTreeNode(data: d),
    DiffNodeData         d => DiffNode(data: d),
    EditorNodeData       d => EditorNode(data: d),
    FilePanelNodeData    d => FilePanelNode(data: d),
    RunNodeData          d => RunNode(data: d),
    MindMapPluginNodeData d => MindMapPluginRegistry.instance.buildWidget(d),
  };

  /// Whether a node should have a user-resizable handle.
  static bool isResizable(MindMapNodeData data) => switch (data) {
    AgentNodeData()           => true,
    FilesNodeData()           => true,
    FileTreeNodeData()        => true,
    DiffNodeData()            => true,
    EditorNodeData()          => true,
    FilePanelNodeData()       => true,
    MindMapPluginNodeData  d  => MindMapPluginRegistry.instance.isResizable(d),
    _                         => false,
  };

  /// Minimum resize size.
  static Size minResizeSize(MindMapNodeData data) => switch (data) {
    AgentNodeData()           => const Size(240, 140),
    FilesNodeData()           => const Size(180, 100),
    FileTreeNodeData()        => const Size(240, 200),
    DiffNodeData()            => const Size(260, 220),
    EditorNodeData()          => const Size(280, 160),
    FilePanelNodeData()       => const Size(280, 160),
    RunNodeData()             => const Size(280, 180),
    WorkspaceNodeData()       => const Size(160, 76),
    SessionNodeData()         => const Size(180, 76),
    MindMapPluginNodeData  d  => MindMapPluginRegistry.instance.minResizeSize(d),
    _                         => const Size(140, 76),
  };
}


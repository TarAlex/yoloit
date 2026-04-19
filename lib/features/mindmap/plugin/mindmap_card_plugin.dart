import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

/// The contract every mindmap card plugin must implement.
///
/// **To create a new card plugin:**
/// ```dart
/// class MyPlugin extends MindMapCardPlugin {
///   @override String get pluginId    => 'com.example.my-plugin';
///   @override String get displayName => 'My Cards';
///   @override IconData get icon      => Icons.extension;
///   @override String get typeTag     => 'myplugin';
///
///   @override
///   Widget buildWidget(MindMapPluginNodeData data) =>
///       MyCardWidget(payload: data.payload);
///
///   @override
///   List<PluginNodeEntry> provideNodes(BuildContext context) {
///     // Read your own BloCs here via context.read<...>() and return nodes.
///     return [
///       PluginNodeEntry(
///         data: MindMapPluginNodeData(
///           id:          'myplugin:main',
///           pluginId:    pluginId,
///           columnIndex: 9,   // place in a new column to the right
///           typeTag:     typeTag,
///           defaultSize: const Size(260, 180),
///           payload:     {'title': 'Hello from plugin'},
///         ),
///       ),
///     ];
///   }
/// }
/// ```
/// Then register at app startup:
/// ```dart
/// MindMapPluginRegistry.instance.register(MyPlugin());
/// ```
abstract class MindMapCardPlugin {
  // ── Identity ──────────────────────────────────────────────────────────────

  /// Unique plugin identifier using reverse-domain notation.
  /// Must be globally unique — collisions cause the later plugin to overwrite
  /// the earlier one in the registry. Example: `'com.acme.jira-cards'`.
  String get pluginId;

  /// Human-readable name shown in the sidebar group header.
  String get displayName;

  /// Icon for the sidebar group row.
  IconData get icon;

  /// Short type-tag used for sidebar show/hide toggling.
  /// Must be unique across all plugins. Example: `'jira'`.
  String get typeTag;

  // ── Card behaviour ────────────────────────────────────────────────────────

  /// Whether cards from this plugin show resize handles.
  bool get isResizable => true;

  /// Minimum card size when the user drags a resize handle.
  Size get minResizeSize => const Size(200, 120);

  // ── Rendering ─────────────────────────────────────────────────────────────

  /// Build the card widget for [data].
  /// Only called when `data.pluginId == this.pluginId`.
  Widget buildWidget(MindMapPluginNodeData data);

  // ── Data provision ────────────────────────────────────────────────────────

  /// Called each time the canvas rebuilds (BLoC state change).
  /// Return the list of nodes (and optional connections) this plugin wants
  /// to show on the canvas right now.
  ///
  /// [context] has access to the same BloC tree as the main canvas —
  /// you can call `context.read<YourCubit>()` here.
  ///
  /// Return an empty list if your plugin doesn't auto-provide data
  /// (e.g. nodes are created programmatically by the user).
  List<PluginNodeEntry> provideNodes(BuildContext context) => const [];
}

/// A node (+ optional outgoing connections) returned by [MindMapCardPlugin.provideNodes].
class PluginNodeEntry {
  const PluginNodeEntry({
    required this.data,
    this.connections = const [],
  });

  final MindMapPluginNodeData data;

  /// Connections originating from [data.id].
  /// The `fromId` of each connection is typically `data.id`.
  final List<MindMapConnection> connections;
}

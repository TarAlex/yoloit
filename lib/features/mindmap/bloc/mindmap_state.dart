import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

class MindMapState extends Equatable {
  const MindMapState({
    this.positions = const {},
    this.sizes     = const {},
    this.locked    = const {},
    this.hidden    = const {},
    this.hiddenTypes = const {},
    this.nodes     = const [],
    this.connections = const [],
  });

  /// Node id → canvas offset (top-left corner).
  final Map<String, Offset> positions;

  /// Node id → current rendered size.
  final Map<String, Size> sizes;

  /// Node ids that have been manually dragged and should not be auto-relayouted.
  final Set<String> locked;

  /// Node ids that the user has hidden via the close button.
  final Set<String> hidden;

  /// Group type tags that are currently hidden via the sidebar.
  final Set<String> hiddenTypes;

  /// All node data (re-built when blocs emit new state).
  final List<MindMapNodeData> nodes;

  /// Connections between nodes.
  final List<MindMapConnection> connections;

  MindMapState copyWith({
    Map<String, Offset>? positions,
    Map<String, Size>?   sizes,
    Set<String>?         locked,
    Set<String>?         hidden,
    Set<String>?         hiddenTypes,
    List<MindMapNodeData>? nodes,
    List<MindMapConnection>? connections,
  }) {
    return MindMapState(
      positions:   positions   ?? this.positions,
      sizes:       sizes       ?? this.sizes,
      locked:      locked      ?? this.locked,
      hidden:      hidden      ?? this.hidden,
      hiddenTypes: hiddenTypes ?? this.hiddenTypes,
      nodes:       nodes       ?? this.nodes,
      connections: connections ?? this.connections,
    );
  }

  @override
  List<Object?> get props => [positions, sizes, locked, hidden, hiddenTypes, nodes, connections];
}

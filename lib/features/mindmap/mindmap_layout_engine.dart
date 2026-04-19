import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

/// Column x-offsets for each column index.
/// Column 1 (Sessions) is wide enough for the merged session+terminal card.
/// All columns are offset by 2000 so users have room to pan left freely.
const _columnX = [
  2040.0,  // 0 Workspaces
  2260.0,  // 1 Sessions (merged with terminal) — wide card
  2680.0,  // 2 Repositories
  2900.0,  // 3 Branches
  3100.0,  // 4 Files Changed
  3360.0,  // 5 Editor
  3860.0,  // 6 Runs (attached from session)
  4240.0,  // 7 File Tree (file browser only)
  4580.0,  // 8 Diff / Git Changes
];

const _columnMargin = 20.0;
const _nodeVMargin  = 20.0;
const _canvasStartY = 2000.0; // large offset so users can pan upward freely

/// Per-column override for vertical node spacing. Workspaces use a larger
/// margin so the list breathes.
const _columnVMargin = <int, double>{
  0: 44.0, // Workspaces — more breathing room
};

/// Computes collision-free positions for nodes.
/// - Each node type maps to a fixed column (x).
/// - Y is determined by finding the first free vertical slot in that column.
/// - Existing (user-dragged) positions are preserved when [locked] contains the id.
class MindMapLayoutEngine {
  MindMapLayoutEngine();

  /// Compute positions for [nodes].
  /// [existing] provides previously saved/user-dragged positions (preserved).
  /// Returns a new map with all node ids mapped to their assigned Offset.
  Map<String, Offset> compute({
    required List<MindMapNodeData> nodes,
    required Map<String, Offset> existing,
    required Map<String, Size> sizes,
    Set<String> locked = const {},
  }) {
    final result = <String, Offset>{};

    // Group already-placed rects per column for overlap detection.
    final columnRects = <int, List<Rect>>{};

    // Seed column rects with locked (user-moved) nodes.
    for (final node in nodes) {
      if (locked.contains(node.id) && existing.containsKey(node.id)) {
        final pos  = existing[node.id]!;
        final size = sizes[node.id] ?? node.defaultSize;
        columnRects.putIfAbsent(node.columnIndex, () => []);
        columnRects[node.columnIndex]!.add(Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
        result[node.id] = pos;
      }
    }

    // Place unlocked nodes.
    for (final node in nodes) {
      if (locked.contains(node.id) && existing.containsKey(node.id)) continue;

      // Preserve existing position if it exists and isn't locked out.
      if (existing.containsKey(node.id)) {
        final pos  = existing[node.id]!;
        final size = sizes[node.id] ?? node.defaultSize;
        columnRects.putIfAbsent(node.columnIndex, () => []);
        columnRects[node.columnIndex]!.add(Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
        result[node.id] = pos;
        continue;
      }

      final colIdx = node.columnIndex;
      final x      = colIdx < _columnX.length ? _columnX[colIdx] : _columnX.last + _columnMargin;
      final size   = sizes[node.id] ?? node.defaultSize;

      final occupied = columnRects[colIdx] ?? [];
      final vMargin  = _columnVMargin[colIdx] ?? _nodeVMargin;
      final y = _findFreeY(x, size, occupied, vMargin);

      final pos = Offset(x, y);
      result[node.id] = pos;
      columnRects.putIfAbsent(colIdx, () => []);
      columnRects[colIdx]!.add(Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
    }

    return result;
  }

  double _findFreeY(double x, Size size, List<Rect> occupied, double vMargin) {
    double candidate = _canvasStartY;
    bool fits = false;

    while (!fits) {
      final rect = Rect.fromLTWH(x, candidate, size.width, size.height);
      final collision = occupied.any((r) => r.inflate(vMargin).overlaps(rect));
      if (!collision) {
        fits = true;
      } else {
        // Jump to the bottom of the blocking rect.
        final blockers = occupied.where((r) => r.inflate(vMargin).overlaps(rect));
        final maxBottom = blockers.map((r) => r.bottom).reduce(math.max);
        candidate = maxBottom + vMargin;
      }
    }
    return candidate;
  }

  /// X center of a column — used for drawing column labels.
  static double columnLabelX(int colIdx) =>
      colIdx < _columnX.length ? _columnX[colIdx] : _columnX.last;

  static const columnLabels = [
    'WORKSPACES',
    'SESSIONS / TERMINALS',
    'REPOSITORIES',
    'BRANCHES',
    'FILES CHANGED',
    'EDITOR',
    'RUNS',
    'FILE TREE',
    'DIFF / GIT CHANGES',
  ];
}

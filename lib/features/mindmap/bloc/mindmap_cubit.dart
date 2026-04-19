import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_state.dart';
import 'package:yoloit/features/mindmap/mindmap_layout_engine.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';

class MindMapCubit extends Cubit<MindMapState> {
  MindMapCubit() : super(const MindMapState());

  static const _kPositions   = 'mindmap.positions';
  static const _kLocked      = 'mindmap.locked';
  static const _kSizes       = 'mindmap.sizes';
  static const _kHidden      = 'mindmap.hidden';
  static const _kHiddenTypes = 'mindmap.hiddenTypes';

  final _engine = MindMapLayoutEngine();

  // ── Load persisted positions ──────────────────────────────────────────────

  Future<void> loadPersistedPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final posJson        = prefs.getString(_kPositions);
    final lockedRaw      = prefs.getStringList(_kLocked);
    final sizesJson      = prefs.getString(_kSizes);
    final hiddenRaw      = prefs.getStringList(_kHidden);
    final hiddenTypesRaw = prefs.getStringList(_kHiddenTypes);

    Map<String, Offset> positions = {};
    Set<String> locked = {};
    Set<String> hidden = {};
    Set<String> hiddenTypes = {};
    Map<String, Size> sizes = {};

    if (posJson != null) {
      final map = jsonDecode(posJson) as Map<String, dynamic>;
      map.forEach((k, v) {
        final list = (v as List).cast<double>();
        positions[k] = Offset(list[0], list[1]);
      });
    }
    if (lockedRaw != null) locked = lockedRaw.toSet();
    if (hiddenRaw != null) hidden = hiddenRaw.toSet();
    if (hiddenTypesRaw != null) hiddenTypes = hiddenTypesRaw.toSet();
    if (sizesJson != null) {
      final map = jsonDecode(sizesJson) as Map<String, dynamic>;
      map.forEach((k, v) {
        final list = (v as List).cast<double>();
        sizes[k] = Size(list[0], list[1]);
      });
    }

    emit(state.copyWith(
      positions:   positions,
      locked:      locked,
      sizes:       sizes,
      hidden:      hidden,
      hiddenTypes: hiddenTypes,
    ));

    // If all positions are at (0,0) (corrupted save from first-open bug), clear them.
    if (positions.isNotEmpty &&
        positions.values.every((o) => o.dx < 10 && o.dy < 10)) {
      emit(state.copyWith(positions: {}, locked: {}, sizes: {}));
      await prefs.remove(_kPositions);
      await prefs.remove(_kLocked);
      await prefs.remove(_kSizes);
    }
  }

  // ── Update nodes (called when blocs emit) ─────────────────────────────────

  void updateNodes(
    List<MindMapNodeData> nodes,
    List<MindMapConnection> connections,
  ) {
    final newPositions = _engine.compute(
      nodes:    nodes,
      existing: state.positions,
      sizes:    state.sizes,
      locked:   state.locked,
    );
    emit(state.copyWith(
      nodes:       nodes,
      connections: connections,
      positions:   newPositions,
    ));
    _savePositions(newPositions);
  }

  // ── Drag ──────────────────────────────────────────────────────────────────

  void moveNode(String id, Offset delta) {
    final current = state.positions[id] ?? Offset.zero;
    final newPos  = Offset(
      current.dx + delta.dx,
      current.dy + delta.dy,
    );
    final newPositions = Map<String, Offset>.from(state.positions)..[id] = newPos;
    final newLocked    = {...state.locked, id};
    emit(state.copyWith(positions: newPositions, locked: newLocked));
    _savePositions(newPositions);
    _saveLocked(newLocked);
  }

  // ── Resize ────────────────────────────────────────────────────────────────

  void resizeNode(String id, Offset delta, Size minSize) {
    final current = state.sizes[id] ?? const Size(200, 200);
    final newSize = Size(
      (current.width  + delta.dx).clamp(minSize.width,  double.infinity),
      (current.height + delta.dy).clamp(minSize.height, double.infinity),
    );
    final newSizes = Map<String, Size>.from(state.sizes)..[id] = newSize;
    emit(state.copyWith(sizes: newSizes));
    _saveSizes(newSizes);
  }

  /// Resize from the left edge: adjusts both position.x and size.width.
  void resizeFromLeft(String id, double dx, Size minSize) {
    final currentPos  = state.positions[id]  ?? Offset.zero;
    final currentSize = state.sizes[id]      ?? const Size(200, 200);

    final newWidth    = (currentSize.width - dx).clamp(minSize.width, double.infinity);
    final clampedDx   = currentSize.width - newWidth;
    final newPos      = Offset(currentPos.dx + clampedDx, currentPos.dy);
    final newSize     = Size(newWidth, currentSize.height);

    final newPositions = Map<String, Offset>.from(state.positions)..[id] = newPos;
    final newSizes     = Map<String, Size>.from(state.sizes)..[id]       = newSize;
    final newLocked    = {...state.locked, id};

    emit(state.copyWith(positions: newPositions, sizes: newSizes, locked: newLocked));
    _savePositions(newPositions);
    _saveSizes(newSizes);
    _saveLocked(newLocked);
  }

  /// Returns the current rendered size of [id], falling back to default.
  Size sizeOf(String id, Size fallback) => state.sizes[id] ?? fallback;

  // ── Hide / show ───────────────────────────────────────────────────────────

  void hideNode(String id) {
    final newHidden = {...state.hidden, id};
    emit(state.copyWith(hidden: newHidden));
    _saveHidden(newHidden);
  }

  void showAllNodes() {
    emit(state.copyWith(hidden: {}, hiddenTypes: {}));
    _saveHidden({});
    _saveHiddenTypes({});
  }

  /// Toggle whether all nodes with a given [typeTag] are hidden.
  void toggleType(String typeTag) {
    final newTypes = {...state.hiddenTypes};
    if (newTypes.contains(typeTag)) {
      newTypes.remove(typeTag);
    } else {
      newTypes.add(typeTag);
    }
    emit(state.copyWith(hiddenTypes: newTypes));
    _saveHiddenTypes(newTypes);
  }

  /// Unhide a single node id (remove from hidden set).
  void showNode(String id) {
    if (!state.hidden.contains(id)) return;
    final newHidden = {...state.hidden}..remove(id);
    emit(state.copyWith(hidden: newHidden));
    _saveHidden(newHidden);
  }

  // ── Reset layout ──────────────────────────────────────────────────────────

  void resetLayout() {
    final newPositions = _engine.compute(
      nodes:    state.nodes,
      existing: {},
      sizes:    state.sizes,
      locked:   {},
    );
    emit(state.copyWith(positions: newPositions, locked: {}, hidden: {}, hiddenTypes: {}));
    _savePositions(newPositions);
    _saveLocked({});
    _saveHidden({});
    _saveHiddenTypes({});
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _savePositions(Map<String, Offset> pos) async {
    final prefs = await SharedPreferences.getInstance();
    final map = pos.map((k, v) => MapEntry(k, [v.dx, v.dy]));
    await prefs.setString(_kPositions, jsonEncode(map));
  }

  Future<void> _saveSizes(Map<String, Size> sizes) async {
    final prefs = await SharedPreferences.getInstance();
    final map = sizes.map((k, v) => MapEntry(k, [v.width, v.height]));
    await prefs.setString(_kSizes, jsonEncode(map));
  }

  Future<void> _saveLocked(Set<String> locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kLocked, locked.toList());
  }

  Future<void> _saveHidden(Set<String> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHidden, hidden.toList());
  }

  Future<void> _saveHiddenTypes(Set<String> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHiddenTypes, types.toList());
  }
}

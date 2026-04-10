import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/core/session/session_prefs.dart';
import 'package:yoloit/core/services/git_service.dart';
import 'package:yoloit/features/workspaces/bloc/workspace_state.dart';
import 'package:yoloit/features/workspaces/models/workspace.dart';

class WorkspaceCubit extends Cubit<WorkspaceState> {
  WorkspaceCubit() : super(const WorkspaceInitial());

  static const _storageKey = 'workspaces';

  /// Default palette for auto-assigning workspace accent colours.
  static const _kWorkspacePalette = [
    Color(0xFF7C3AED), // violet
    Color(0xFF2563EB), // blue
    Color(0xFF059669), // emerald
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
    Color(0xFF0891B2), // cyan
    Color(0xFFDB2777), // pink
    Color(0xFF65A30D), // lime
    Color(0xFF9333EA), // purple
    Color(0xFFEA580C), // orange
  ];

  Future<void> load() async {
    emit(const WorkspaceLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getStringList(_storageKey) ?? [];
      final workspaces = json
          .map((s) => Workspace.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
      final snap = await SessionPrefs.load();
      final savedId = snap.activeWorkspaceId;
      final activeId = savedId != null && workspaces.any((w) => w.id == savedId)
          ? savedId
          : (workspaces.length == 1 ? workspaces.first.id : null);
      emit(WorkspaceLoaded(workspaces: workspaces, activeWorkspaceId: activeId));
      // Refresh git info for all workspaces
      for (final ws in workspaces) {
        _refreshGitInfo(ws.id);
      }
    } catch (e) {
      emit(WorkspaceError(e.toString()));
    }
  }

  Future<void> addWorkspace(String folderPath) async {
    final name = p.basename(folderPath);
    final id = '${name}_${DateTime.now().millisecondsSinceEpoch}';
    final current = _currentLoaded;
    if (current == null) return;
    // Assign a default accent colour cycling through the palette.
    final defaultColor = _kWorkspacePalette[current.workspaces.length % _kWorkspacePalette.length];
    final workspace = Workspace(id: id, name: name, path: folderPath, color: defaultColor);
    final updated = [...current.workspaces, workspace];
    emit(current.copyWith(workspaces: updated));
    await _save(updated);
    await _refreshGitInfo(id);
  }

  Future<void> removeWorkspace(String id) async {
    final current = _currentLoaded;
    if (current == null) return;
    final updated = current.workspaces.where((w) => w.id != id).toList();
    final newActiveId = current.activeWorkspaceId == id ? null : current.activeWorkspaceId;
    emit(WorkspaceLoaded(workspaces: updated, activeWorkspaceId: newActiveId));
    await _save(updated);
  }

  void setActive(String id) {
    final current = _currentLoaded;
    if (current == null) return;
    emit(current.copyWith(activeWorkspaceId: id));
    SessionPrefs.saveActiveWorkspaceId(id);
  }

  Future<void> setWorkspaceColor(String id, Color? color) async {
    final current = _currentLoaded;
    if (current == null) return;
    final updated = current.workspaces.map((w) {
      if (w.id != id) return w;
      return color == null ? w.copyWith(clearColor: true) : w.copyWith(color: color);
    }).toList();
    emit(current.copyWith(workspaces: updated));
    await _save(updated);
  }

  Future<void> refreshAll() async {
    final current = _currentLoaded;
    if (current == null) return;
    for (final ws in current.workspaces) {
      await _refreshGitInfo(ws.id);
    }
  }

  Future<void> _refreshGitInfo(String id) async {
    final current = _currentLoaded;
    if (current == null) return;
    final ws = current.workspaces.firstWhere((w) => w.id == id, orElse: () => throw StateError(''));
    try {
      final branch = await GitService.instance.getBranch(ws.path);
      final stats = await GitService.instance.getDiffStats(ws.path);
      final updated = current.workspaces.map((w) {
        if (w.id == id) {
          return w.copyWith(
            gitBranch: branch,
            addedLines: stats.added,
            removedLines: stats.removed,
          );
        }
        return w;
      }).toList();
      if (state is WorkspaceLoaded) {
        emit((state as WorkspaceLoaded).copyWith(workspaces: updated));
      }
    } catch (_) {}
  }

  Future<void> _save(List<Workspace> workspaces) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      workspaces.map((w) => jsonEncode(w.toJson())).toList(),
    );
  }

  WorkspaceLoaded? get _currentLoaded {
    final s = state;
    if (s is WorkspaceLoaded) return s;
    if (s is WorkspaceInitial || s is WorkspaceLoading) {
      return const WorkspaceLoaded(workspaces: []);
    }
    return null;
  }
}

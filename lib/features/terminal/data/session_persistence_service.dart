import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

/// Persists active terminal session metadata across app restarts, keyed per workspace.
class SessionPersistenceService {
  SessionPersistenceService._();
  static final instance = SessionPersistenceService._();

  static String _key(String workspaceId) => 'terminal_sessions_v2_$workspaceId';

  /// Saves sessions for a specific workspace.
  Future<void> save(List<AgentSession> sessions, String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = sessions
        .map((s) => {
              'id': s.id,
              'type': s.type.name,
              'workspacePath': s.workspacePath,
              'workspaceId': s.workspaceId ?? workspaceId,
              if (s.customName != null) 'customName': s.customName,
              if (s.worktreeContexts != null && s.worktreeContexts!.isNotEmpty)
                'worktreeContexts': s.worktreeContexts,
            })
        .toList();
    await prefs.setString(_key(workspaceId), jsonEncode(data));
  }

  /// Returns saved session descriptors for a workspace, filtering deleted paths.
  Future<List<SavedSession>> load(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(workspaceId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final results = <SavedSession>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final typeName = map['type'] as String? ?? '';
        final type = AgentType.values.where((t) => t.name == typeName).firstOrNull;
        if (type == null) continue;
        final path = map['workspacePath'] as String? ?? '';
        if (!Directory(path).existsSync()) continue;

        // Restore worktreeContexts if saved.
        Map<String, String>? worktreeContexts;
        final wtRaw = map['worktreeContexts'];
        if (wtRaw is Map) {
          worktreeContexts = Map<String, String>.from(
            wtRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
          );
          // Filter out stale entries where the worktree path no longer exists.
          worktreeContexts.removeWhere((_, v) => !Directory(v).existsSync());
          if (worktreeContexts.isEmpty) worktreeContexts = null;
        }

        results.add(SavedSession(
          id: map['id'] as String? ?? '',
          type: type,
          workspacePath: path,
          workspaceId: map['workspaceId'] as String? ?? workspaceId,
          customName: map['customName'] as String?,
          worktreeContexts: worktreeContexts,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearWorkspace(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(workspaceId));
  }
}

class SavedSession {
  const SavedSession({
    required this.id,
    required this.type,
    required this.workspacePath,
    this.workspaceId,
    this.customName,
    this.worktreeContexts,
  });

  final String id;
  final AgentType type;
  final String workspacePath;
  final String? workspaceId;
  final String? customName;
  final Map<String, String>? worktreeContexts;
}

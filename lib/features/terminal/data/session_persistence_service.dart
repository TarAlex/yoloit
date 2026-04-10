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
            })
        .toList();
    await prefs.setString(_key(workspaceId), jsonEncode(data));
  }

  /// Returns saved session descriptors for a workspace, filtering deleted paths.
  Future<List<_SavedSession>> load(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(workspaceId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final results = <_SavedSession>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final typeName = map['type'] as String? ?? '';
        final type = AgentType.values.where((t) => t.name == typeName).firstOrNull;
        if (type == null) continue;
        final path = map['workspacePath'] as String? ?? '';
        if (!Directory(path).existsSync()) continue;
        results.add(_SavedSession(
          id: map['id'] as String? ?? '',
          type: type,
          workspacePath: path,
          workspaceId: map['workspaceId'] as String? ?? workspaceId,
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

class _SavedSession {
  const _SavedSession({
    required this.id,
    required this.type,
    required this.workspacePath,
    this.workspaceId,
  });

  final String id;
  final AgentType type;
  final String workspacePath;
  final String? workspaceId;
}

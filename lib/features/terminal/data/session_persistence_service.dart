import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/terminal/models/agent_session.dart';
import 'package:yoloit/features/terminal/models/agent_type.dart';

/// Persists active terminal session metadata across app restarts.
///
/// Terminal output (scrollback) cannot be saved because it lives inside the
/// PTY process.  What we save is enough to re-spawn identical sessions: agent
/// type, workspace path, and workspace id (for secrets injection).
class SessionPersistenceService {
  SessionPersistenceService._();
  static final instance = SessionPersistenceService._();

  static const _key = 'terminal_sessions_v1';

  /// Saves the current list of sessions.  Call after any mutation.
  Future<void> save(List<AgentSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final data = sessions
        .map(
          (s) => {
            'id': s.id,
            'type': s.type.name,
            'workspacePath': s.workspacePath,
            if (s.workspaceId != null) 'workspaceId': s.workspaceId,
          },
        )
        .toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Returns saved session descriptors, filtering out workspaces whose paths
  /// no longer exist on disk.
  Future<List<_SavedSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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

        results.add(
          _SavedSession(
            id: map['id'] as String? ?? '',
            type: type,
            workspacePath: path,
            workspaceId: map['workspaceId'] as String?,
          ),
        );
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
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

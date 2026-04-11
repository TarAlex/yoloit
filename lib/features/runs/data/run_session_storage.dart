import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/runs/models/run_session.dart';

/// Persists completed/stopped run sessions (with their output) per workspace
/// so they can be restored after the app restarts.
///
/// Only non-running sessions are persisted (running sessions are ephemeral —
/// the process is gone after restart anyway, so we mark them as stopped).
class RunSessionStorage {
  RunSessionStorage._();
  static final instance = RunSessionStorage._();

  static const _maxSavedSessions = 10;
  static const _maxSavedOutputLines = 1000;

  String _key(String workspacePath) => 'run_sessions_$workspacePath';

  Future<List<RunSession>> load(String workspacePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(workspacePath));
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RunSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String workspacePath, List<RunSession> sessions) async {
    try {
      // Persist all non-idle sessions. Running sessions are saved with their
      // running status so loadForWorkspace can attempt tmux reconnection.
      final toSave = sessions
          .where((s) => s.status != RunStatus.idle)
          .toList();

      // Keep only the most recent N sessions.
      final trimmed = toSave.length > _maxSavedSessions
          ? toSave.sublist(toSave.length - _maxSavedSessions)
          : toSave;

      // Trim output per session so we don't bloat prefs.
      final capped = trimmed.map((s) {
        if (s.output.length <= _maxSavedOutputLines) return s;
        return s.copyWith(
          output: s.output.sublist(s.output.length - _maxSavedOutputLines),
        );
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(workspacePath),
        jsonEncode(capped.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }
}

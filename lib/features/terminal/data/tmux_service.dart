import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages tmux sessions as a backend for persistent terminal sessions.
///
/// When tmux is available and enabled, each terminal session runs inside a
/// named tmux session.  Closing the app detaches from tmux but does NOT kill
/// the session — the agent keeps running.  On next launch the cubit attaches
/// back to the existing session.
class TmuxService {
  TmuxService._();
  static final instance = TmuxService._();

  static const _enabledKey = 'tmux_enabled_v1';

  bool _enabled = false;
  bool get enabled => _enabled;

  bool _available = false;
  bool get available => _available;

  /// Must be called once at startup before using any other methods.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _available = await _checkAvailable();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  bool get isActive => _enabled && _available;

  static Future<bool> _checkAvailable() async {
    try {
      final result = await Process.run('which', ['tmux']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Sanitises a session ID to be safe as a tmux session name.
  static String tmuxName(String sessionId) =>
      sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// Creates or attaches to a named tmux session and returns a PTY connected
  /// to it.  Uses `new-session -A` which creates if absent, attaches if found.
  Pty launch({
    required String sessionId,
    required String workspacePath,
    required Map<String, String> env,
    int columns = 220,
    int rows = 50,
  }) {
    return Pty.start(
      'tmux',
      arguments: [
        'new-session',
        '-A', // create if absent, attach if present
        '-s', tmuxName(sessionId),
        '-c', workspacePath,
      ],
      environment: env,
      columns: columns,
      rows: rows,
    );
  }

  /// Kills the underlying tmux session (called when user explicitly closes a
  /// tab — NOT called on app exit, allowing the session to survive).
  Future<void> killSession(String sessionId) async {
    await Process.run('tmux', ['kill-session', '-t', tmuxName(sessionId)]);
  }

  Future<List<String>> listSessions() async {
    try {
      final result = await Process.run(
        'tmux',
        ['list-sessions', '-F', '#{session_name}'],
      );
      if (result.exitCode != 0) return [];
      return (result.stdout as String)
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> sessionExists(String sessionId) async {
    final sessions = await listSessions();
    return sessions.contains(tmuxName(sessionId));
  }
}

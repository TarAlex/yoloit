import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';

class PtyService {
  PtyService._();
  static final PtyService instance = PtyService._();

  final Map<String, Pty> _ptys = {};
  // Tracks which sessions are backed by tmux (should NOT be killed on app exit).
  final Set<String> _tmuxSessions = {};

  Pty? getPty(String sessionId) => _ptys[sessionId];

  Pty launch({
    required String sessionId,
    required String workspacePath,
    Map<String, String>? extraEnv,
  }) {
    final existing = _ptys[sessionId];
    if (existing != null) {
      existing.kill();
      _ptys.remove(sessionId);
    }

    final env = <String, String>{
      ...Platform.environment,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      if (extraEnv != null) ...extraEnv,
    };

    // Use the user's default shell
    final shell = Platform.environment['SHELL'] ?? '/bin/zsh';

    final pty = Pty.start(
      shell,
      workingDirectory: workspacePath,
      environment: env,
      columns: 220,
      rows: 50,
    );

    _ptys[sessionId] = pty;
    return pty;
  }

  /// Launches a PTY connected to an existing (or new) tmux session.
  Pty launchTmux({
    required String sessionId,
    required String workspacePath,
    required Pty Function({
      required String sessionId,
      required String workspacePath,
      required Map<String, String> env,
      int columns,
      int rows,
    }) tmuxLauncher,
    Map<String, String>? extraEnv,
  }) {
    final existing = _ptys[sessionId];
    if (existing != null) {
      existing.kill();
      _ptys.remove(sessionId);
    }

    final env = <String, String>{
      ...Platform.environment,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      if (extraEnv != null) ...extraEnv,
    };

    final pty = tmuxLauncher(
      sessionId: sessionId,
      workspacePath: workspacePath,
      env: env,
      columns: 220,
      rows: 50,
    );

    _ptys[sessionId] = pty;
    _tmuxSessions.add(sessionId);
    return pty;
  }

  void write(String sessionId, String data) {
    final pty = _ptys[sessionId];
    if (pty == null) return;
    pty.write(const Utf8Encoder().convert(data));
  }

  void resize(String sessionId, int columns, int rows) {
    // flutter_pty Pty.resize(rows, cols) — note the order!
    _ptys[sessionId]?.resize(rows, columns);
  }

  /// Kills the PTY and, if it is a tmux session, also kills the tmux session.
  /// Use this when the user explicitly closes a tab.
  void kill(String sessionId, {Future<void> Function(String)? onKillTmux}) {
    _ptys[sessionId]?.kill();
    _ptys.remove(sessionId);
    if (_tmuxSessions.remove(sessionId) && onKillTmux != null) {
      onKillTmux(sessionId);
    }
  }

  /// Detaches all PTYs without killing tmux sessions (called on app exit).
  void killAll() {
    for (final pty in _ptys.values) {
      pty.kill();
    }
    _ptys.clear();
    _tmuxSessions.clear();
  }
}

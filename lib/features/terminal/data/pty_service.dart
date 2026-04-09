import 'dart:convert';
import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';

class PtyService {
  PtyService._();
  static final PtyService instance = PtyService._();

  final Map<String, Pty> _ptys = {};

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

  void write(String sessionId, String data) {
    final pty = _ptys[sessionId];
    if (pty == null) return;
    pty.write(const Utf8Encoder().convert(data));
  }

  void resize(String sessionId, int columns, int rows) {
    // flutter_pty Pty.resize(rows, cols) — note the order!
    _ptys[sessionId]?.resize(rows, columns);
  }

  void kill(String sessionId) {
    _ptys[sessionId]?.kill();
    _ptys.remove(sessionId);
  }

  void killAll() {
    for (final pty in _ptys.values) {
      pty.kill();
    }
    _ptys.clear();
  }
}

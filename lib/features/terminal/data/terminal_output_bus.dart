import 'dart:async';

/// Singleton bus that carries raw PTY output for all terminal sessions.
/// CollaborationCubit subscribes to this to stream terminal data to browser guests.
class TerminalOutputBus {
  TerminalOutputBus._();
  static final instance = TerminalOutputBus._();

  /// (sessionId, plainTextData) pairs.
  final StreamController<(String, String)> _ctrl =
      StreamController.broadcast();

  Stream<(String, String)> get stream => _ctrl.stream;

  void write(String sessionId, String data) {
    if (!_ctrl.isClosed) _ctrl.add((sessionId, data));
  }

  void dispose() => _ctrl.close();
}

// Strips the most common ANSI escape sequences so output is readable in browser.
String stripAnsi(String s) => s.replaceAll(
    RegExp(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])'), '');

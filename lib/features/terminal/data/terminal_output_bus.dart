import 'dart:async';

/// Singleton bus that carries raw PTY output for all terminal sessions.
/// CollaborationCubit subscribes to this to stream terminal data to browser guests.
class TerminalOutputBus {
  TerminalOutputBus._();
  static final instance = TerminalOutputBus._();

  /// (sessionId, rawData) pairs. rawData contains raw PTY bytes with ANSI
  /// sequences intact — web guests pipe this into their xterm Terminal.
  final StreamController<(String, String)> _ctrl =
      StreamController.broadcast();

  Stream<(String, String)> get stream => _ctrl.stream;

  void write(String sessionId, String data) {
    if (!_ctrl.isClosed) _ctrl.add((sessionId, data));
  }

  void dispose() => _ctrl.close();
}

// Strips ANSI/VT100 escape sequences including CSI, OSC, character-set
// designations (ESC ( B etc.) and two-byte Fe sequences.
String stripAnsi(String s) {
  return s
      // CSI sequences: ESC [ ... final-byte
      .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
      // OSC sequences: ESC ] ... ST  (ST = BEL or ESC \)
      .replaceAll(RegExp(r'\x1B\].*?(?:\x07|\x1B\\)'), '')
      // Character-set designations: ESC ( X  ESC ) X  ESC * X  ESC + X
      .replaceAll(RegExp(r'\x1B[()* +][A-Za-z0-9]'), '')
      // Two-byte Fe sequences: ESC followed by 0x40–0x5F (except [, ], etc.)
      .replaceAll(RegExp(r'\x1B[@-Z\\-_]'), '')
      // Catch-all: any remaining lone ESC followed by a non-space printable char
      .replaceAll(RegExp(r'\x1B[^\x1B\n]?'), '');
}

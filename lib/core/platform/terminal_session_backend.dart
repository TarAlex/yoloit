/// Abstract backend for persistent terminal sessions.
///
/// Implementations:
/// - [TmuxSessionBackend] — macOS/Linux, backed by a tmux session.
/// - [ConPtySessionBackend] — Windows stub (not yet implemented).
///
/// Callers (`RunService`, `TmuxService`) interact with sessions via this
/// interface so that the underlying mechanism can be swapped per platform.
abstract class TerminalSessionBackend {
  const TerminalSessionBackend();

  /// Sanitises an arbitrary session ID to be safe as a backend session name.
  static String sanitiseName(String sessionId) =>
      sessionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  /// Starts a new terminal session running [command] in [workingDir].
  Future<void> start({
    required String sessionId,
    required String command,
    required String workingDir,
    Map<String, String> env = const {},
  });

  /// Attempts to reconnect to an existing session.
  /// Returns `true` if the session was found and reconnected.
  Future<bool> reconnect(String sessionId);

  /// Stops the session, cleaning up resources.
  Future<void> stop(String sessionId);

  /// Sends key input to the session (equivalent to typing in the terminal).
  Future<void> sendKeys(String sessionId, String keys);

  /// Returns the path to the log file for [sessionId], creating it if needed.
  Future<String> logPath(String sessionId);
}

// ── Stub for Windows (ConPTY) ─────────────────────────────────────────────────

/// Windows ConPTY backend — not yet implemented.
/// All methods throw [UnsupportedError].
class ConPtySessionBackend extends TerminalSessionBackend {
  const ConPtySessionBackend();

  @override
  Future<void> start({
    required String sessionId,
    required String command,
    required String workingDir,
    Map<String, String> env = const {},
  }) =>
      throw UnsupportedError('ConPTY backend is not yet implemented.');

  @override
  Future<bool> reconnect(String sessionId) =>
      throw UnsupportedError('ConPTY backend is not yet implemented.');

  @override
  Future<void> stop(String sessionId) =>
      throw UnsupportedError('ConPTY backend is not yet implemented.');

  @override
  Future<void> sendKeys(String sessionId, String keys) =>
      throw UnsupportedError('ConPTY backend is not yet implemented.');

  @override
  Future<String> logPath(String sessionId) =>
      throw UnsupportedError('ConPTY backend is not yet implemented.');
}

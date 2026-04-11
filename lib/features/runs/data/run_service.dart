import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef OutputCallback = void Function(String line, bool isError);
typedef ExitCallback = void Function(int exitCode);

class RunService {
  RunService._();
  static final instance = RunService._();

  final Map<String, String> _sessionTmux = {};
  final Map<String, Process> _tails = {};
  final Map<String, List<StreamSubscription>> _subs = {};

  static String tmuxName(String configId) =>
      'yoloit_run_${configId.replaceAll(RegExp(r"[^a-zA-Z0-9]"), "_")}';

  static Future<String> logPath(String configId) async {
    final home = Platform.environment["HOME"] ?? "/tmp";
    final dir = Directory("$home/.config/yoloit/runs");
    await dir.create(recursive: true);
    return "${dir.path}/${tmuxName(configId)}.log";
  }

  Future<void> start({
    required String sessionId,
    required String configId,
    required String command,
    required String workingDir,
    Map<String, String> env = const {},
    required OutputCallback onOutput,
    required ExitCallback onExit,
  }) async {
    final name = tmuxName(configId);
    final log = await logPath(configId);
    _sessionTmux[sessionId] = name;

    await File(log).writeAsString("");
    await Process.run("tmux", ["kill-session", "-t", name]);

    final envStr = env.entries
        .map((e) => "export ${e.key}=\"${e.value}\"")
        .join("; ");
    final prefix = envStr.isNotEmpty ? "$envStr; " : "";
    final bash = "${prefix}cd \"\$YOLOIT_DIR\" && $command 2>&1 | tee \"\$YOLOIT_LOG\"; "
        "echo \"__YOLOIT_EXIT_\$?\" >> \"\$YOLOIT_LOG\"";

    final result = await Process.run(
      "tmux",
      ["new-session", "-d", "-s", name, "-x", "220", "-y", "50",
       "bash", "-c", bash],
      environment: {
        ...Platform.environment,
        "YOLOIT_DIR": workingDir,
        "YOLOIT_LOG": log,
      },
    );

    if (result.exitCode != 0) {
      onOutput("Failed to start tmux session: ${result.stderr}", true);
      onExit(1);
      return;
    }

    await _tailLog(
      sessionId: sessionId, log: log, fromStart: true,
      onOutput: onOutput, onExit: onExit,
    );
  }

  Future<bool> reconnect({
    required String sessionId,
    required String configId,
    required OutputCallback onOutput,
    required ExitCallback onExit,
  }) async {
    final name = tmuxName(configId);
    final check = await Process.run("tmux", ["has-session", "-t", name]);
    if (check.exitCode != 0) return false;
    _sessionTmux[sessionId] = name;
    final log = await logPath(configId);
    await _tailLog(
      sessionId: sessionId, log: log, fromStart: false,
      onOutput: onOutput, onExit: onExit,
    );
    return true;
  }

  Future<void> _tailLog({
    required String sessionId,
    required String log,
    required bool fromStart,
    required OutputCallback onOutput,
    required ExitCallback onExit,
  }) async {
    final args = fromStart ? ["-n", "+1", "-F", log] : ["-n", "0", "-F", log];
    final tail = await Process.start("tail", args);
    _tails[sessionId] = tail;

    final outSub = tail.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.startsWith("__YOLOIT_EXIT_")) {
        final code = int.tryParse(line.substring("__YOLOIT_EXIT_".length)) ?? 0;
        _cleanup(sessionId);
        onExit(code);
      } else {
        onOutput(line, false);
      }
    });

    final errSub = tail.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});

    _subs[sessionId] = [outSub, errSub];
  }

  void stop(String sessionId) {
    final name = _sessionTmux[sessionId];
    if (name != null) Process.run("tmux", ["kill-session", "-t", name]);
    _cleanup(sessionId);
  }

  void sendHotReload(String sessionId) => _sendKeys(sessionId, "r");
  void sendHotRestart(String sessionId) => _sendKeys(sessionId, "R");
  void sendStdin(String sessionId, String text) => _sendKeys(sessionId, text);

  void _sendKeys(String sessionId, String keys) {
    final name = _sessionTmux[sessionId];
    if (name != null) Process.run("tmux", ["send-keys", "-t", name, keys, ""]);
  }

  bool isRunning(String sessionId) => _tails.containsKey(sessionId);

  void _cleanup(String sessionId) {
    for (final sub in _subs[sessionId] ?? []) sub.cancel();
    final proc = _tails.remove(sessionId);
    if (proc != null) proc.kill(ProcessSignal.sigterm);
    _subs.remove(sessionId);
    _sessionTmux.remove(sessionId);
  }
}

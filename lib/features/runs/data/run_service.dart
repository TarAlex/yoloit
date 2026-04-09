import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef OutputCallback = void Function(String line, bool isError);
typedef ExitCallback = void Function(int exitCode);

class RunService {
  RunService._();
  static final instance = RunService._();

  final Map<String, Process> _processes = {};
  final Map<String, StreamSubscription<String>> _stdoutSubs = {};
  final Map<String, StreamSubscription<String>> _stderrSubs = {};

  Future<void> start({
    required String sessionId,
    required String command,
    required String workingDir,
    Map<String, String> env = const {},
    required OutputCallback onOutput,
    required ExitCallback onExit,
  }) async {
    final parts = _parseCommand(command);
    final executable = parts.first;
    final args = parts.skip(1).toList();

    final fullEnv = Map<String, String>.from(Platform.environment)..addAll(env);

    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDir,
      environment: fullEnv,
      runInShell: true,
    );

    _processes[sessionId] = process;

    _stdoutSubs[sessionId] = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => onOutput(line, false));

    _stderrSubs[sessionId] = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => onOutput(line, true));

    process.exitCode.then((code) {
      _cleanup(sessionId);
      onExit(code);
    });
  }

  void stop(String sessionId) {
    _processes[sessionId]?.kill(ProcessSignal.sigterm);
    _cleanup(sessionId);
  }

  void sendStdin(String sessionId, String text) {
    _processes[sessionId]?.stdin.write(text);
  }

  bool isRunning(String sessionId) => _processes.containsKey(sessionId);

  void _cleanup(String sessionId) {
    _stdoutSubs[sessionId]?.cancel();
    _stderrSubs[sessionId]?.cancel();
    _stdoutSubs.remove(sessionId);
    _stderrSubs.remove(sessionId);
    _processes.remove(sessionId);
  }

  List<String> _parseCommand(String command) {
    final result = <String>[];
    final current = StringBuffer();
    var inQuotes = false;
    var quoteChar = '';
    for (final char in command.split('')) {
      if (inQuotes) {
        if (char == quoteChar) {
          inQuotes = false;
        } else {
          current.write(char);
        }
      } else if (char == '"' || char == "'") {
        inQuotes = true;
        quoteChar = char;
      } else if (char == ' ' && current.isNotEmpty) {
        result.add(current.toString());
        current.clear();
      } else if (char != ' ') {
        current.write(char);
      }
    }
    if (current.isNotEmpty) result.add(current.toString());
    return result;
  }
}

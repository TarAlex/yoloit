import 'dart:convert';
import 'dart:io';

/// Captures [Process.run]-style calls for unit testing platform services.
///
/// Usage:
/// ```dart
/// final runner = FakeProcessRunner();
/// runner.mockResult('open', exitCode: 0, stdout: '');
/// final svc = MacosPlatformLauncher(processRunner: runner.run);
/// await svc.openUrl('https://example.com');
/// expect(runner.calls.last.executable, 'open');
/// ```
class FakeProcessRunner {
  final List<ProcessCall> calls = [];
  final Map<String, ProcessResult> _results = {};

  /// Registers a result to return when [executable] is invoked.
  void mockResult(
    String executable, {
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  }) {
    _results[executable] = ProcessResult(0, exitCode, stdout, stderr);
  }

  /// Mimics [Process.run] signature. Returns the registered result or a
  /// success result with empty output if no mock was registered.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    calls.add(ProcessCall(executable: executable, arguments: arguments));
    return _results[executable] ?? ProcessResult(0, 0, '', '');
  }

  ProcessCall? get lastCall => calls.isEmpty ? null : calls.last;

  void reset() {
    calls.clear();
    _results.clear();
  }
}

class ProcessCall {
  final String executable;
  final List<String> arguments;

  const ProcessCall({required this.executable, required this.arguments});

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

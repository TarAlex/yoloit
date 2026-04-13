import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/core/platform/terminal_session_backend.dart';

void main() {
  group('TerminalSessionBackend.sanitiseName', () {
    test('replaces spaces with underscores', () {
      expect(TerminalSessionBackend.sanitiseName('my session'), 'my_session');
    });

    test('replaces dots with underscores', () {
      expect(TerminalSessionBackend.sanitiseName('v0.0.1'), 'v0_0_1');
    });

    test('allows alphanumeric, dash, underscore', () {
      expect(
        TerminalSessionBackend.sanitiseName('abc_def-123'),
        'abc_def-123',
      );
    });

    test('replaces all special chars', () {
      expect(
        TerminalSessionBackend.sanitiseName('a!b@c#d\$e%f^g&h*i(j)k'),
        'a_b_c_d_e_f_g_h_i_j_k',
      );
    });

    test('empty string stays empty', () {
      expect(TerminalSessionBackend.sanitiseName(''), '');
    });

    test('consistent with tmuxName format used in RunService', () {
      // RunService uses: configId.replaceAll(RegExp(r"[^a-zA-Z0-9]"), "_")
      // sanitiseName also allows - (dash) which is valid in tmux names.
      final result = TerminalSessionBackend.sanitiseName('my-run_01');
      expect(result, 'my-run_01');
    });
  });

  group('ConPtySessionBackend', () {
    late ConPtySessionBackend backend;

    setUp(() => backend = const ConPtySessionBackend());

    test('start throws UnsupportedError', () {
      expect(
        () => backend.start(
          sessionId: 'test',
          command: 'echo hello',
          workingDir: '/tmp',
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('reconnect throws UnsupportedError', () {
      expect(
        () => backend.reconnect('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('stop throws UnsupportedError', () {
      expect(
        () => backend.stop('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('sendKeys throws UnsupportedError', () {
      expect(
        () => backend.sendKeys('test', 'r'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('logPath throws UnsupportedError', () {
      expect(
        () => backend.logPath('test'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

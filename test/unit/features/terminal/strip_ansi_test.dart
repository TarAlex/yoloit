import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/terminal/data/terminal_output_bus.dart';

void main() {
  group('stripAnsi', () {
    // --- plain text pass-through ---
    test('returns plain text unchanged', () {
      expect(stripAnsi('hello world'), 'hello world');
    });

    test('returns empty string unchanged', () {
      expect(stripAnsi(''), '');
    });

    test('preserves newlines', () {
      expect(stripAnsi('line1\nline2\n'), 'line1\nline2\n');
    });

    // --- CSI sequences ---
    test('strips SGR color codes', () {
      expect(stripAnsi('\x1b[32mgreen\x1b[0m'), 'green');
    });

    test('strips 256-color SGR', () {
      expect(stripAnsi('\x1b[38;5;196mred\x1b[0m'), 'red');
    });

    test('strips true-color SGR', () {
      expect(stripAnsi('\x1b[38;2;255;100;0morange\x1b[0m'), 'orange');
    });

    test('strips cursor movement CSI', () {
      expect(stripAnsi('\x1b[2Jhello'), 'hello');
      expect(stripAnsi('\x1b[1;1Hhere'), 'here');
    });

    test('strips erase in line', () {
      expect(stripAnsi('foo\x1b[Kbar'), 'foobar');
    });

    // --- OSC sequences ---
    test('strips OSC terminated by BEL', () {
      expect(stripAnsi('\x1b]0;My Title\x07text'), 'text');
    });

    test('strips OSC terminated by ST (ESC \\)', () {
      expect(stripAnsi('\x1b]0;My Title\x1b\\text'), 'text');
    });

    // --- charset designations ---
    test('strips ESC(B (G0 ASCII)', () {
      expect(stripAnsi('\x1b(Btext'), 'text');
    });

    test('strips ESC(0 (G0 DEC line-drawing)', () {
      // 'q' chars are plain ASCII — they only become line-drawing glyphs inside
      // the terminal emulator when G0 is set to DEC Special. stripAnsi removes
      // the escape sequences but keeps the plain text.
      expect(stripAnsi('\x1b(0qqq\x1b(B'), 'qqq');
    });

    test('strips ESC)B (G1 ASCII)', () {
      expect(stripAnsi('\x1b)Btext'), 'text');
    });

    test('strips ESC*B and ESC+B', () {
      expect(stripAnsi('\x1b*Btext\x1b+Bend'), 'textend');
    });

    // --- Fe two-byte sequences ---
    test('strips ESC M (reverse index)', () {
      expect(stripAnsi('\x1bMline'), 'line');
    });

    test('strips ESC = and ESC > (keypad mode)', () {
      expect(stripAnsi('\x1b=text\x1b>end'), 'textend');
    });

    // --- combined real-world patterns ---
    test('strips copilot TUI header', () {
      // Simulated: bold, color, reset, charset reset
      final input = '\x1b[1m\x1b[35m● Copilot\x1b[0m\x1b(B';
      expect(stripAnsi(input), '● Copilot');
    });

    test('strips full SGR reset + charset combo', () {
      // ESC[0m ESC(B is extremely common in practice
      expect(stripAnsi('\x1b[0m\x1b(B'), '');
    });

    test('handles multiple sequences interspersed with text', () {
      final input = '\x1b[32m>\x1b[0m hello \x1b[1mworld\x1b[0m\x1b(B';
      expect(stripAnsi(input), '> hello world');
    });

    test('strips DEC Special Graphics line-drawing sequence', () {
      // ESC(0 lqqqqk ESC(B → stripped to just the line-drawing chars
      final input = '\x1b(0lqqqqk\x1b(B';
      expect(stripAnsi(input), 'lqqqqk');
    });

    test('handles line-drawing chars correctly', () {
      // The 'q' chars themselves are NOT escape sequences — they're just ASCII
      // characters that the terminal remaps when G0=DEC Special. stripAnsi
      // should leave them as-is.
      final input = 'qqqqq';
      expect(stripAnsi(input), 'qqqqq');
    });
  });
}

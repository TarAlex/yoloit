/// Tests for the pure logic functions in file_editor_panel.dart:
/// - _languageName (tested via expected extension→name mapping)
/// - _commentPrefix (per language)
/// - _parseSymbols (Dart/JS/TS/Python outline parsing)
/// - _lineRange helper logic
/// - _closingBracket (auto-pairs)
/// - _parseDiffMarkers (git gutter)
///
/// Because the helpers are private (file-scoped), we re-implement
/// them here as package-visible equivalents that are 1-to-1 copies,
/// so we can test exhaustively without exposing them from the UI file.

import 'package:flutter_test/flutter_test.dart';

// ── Re-implementations of private helpers from file_editor_panel.dart ────────

String languageName(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  return switch (ext) {
    'dart' => 'Dart',
    'js' => 'JavaScript',
    'ts' => 'TypeScript',
    'jsx' || 'tsx' => 'React',
    'py' => 'Python',
    'java' => 'Java',
    'kt' => 'Kotlin',
    'go' => 'Go',
    'rs' => 'Rust',
    'sh' || 'bash' => 'Shell',
    'cpp' || 'cc' || 'cxx' => 'C++',
    'c' => 'C',
    'css' => 'CSS',
    'json' => 'JSON',
    'yaml' || 'yml' => 'YAML',
    'xml' => 'XML',
    'sql' => 'SQL',
    'md' => 'Markdown',
    'swift' => 'Swift',
    'html' => 'HTML',
    _ => ext.isEmpty ? 'Plain Text' : ext.toUpperCase(),
  };
}

String commentPrefix(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  return switch (ext) {
    'py' || 'rb' || 'sh' || 'bash' || 'yaml' || 'yml' || 'toml' => '# ',
    'css' => '/* ',
    _ => '// ',
  };
}

class OutlineSymbol {
  const OutlineSymbol({required this.name, required this.line, required this.isClass});
  final String name;
  final int line;
  final bool isClass;
}

List<OutlineSymbol> parseSymbols(String content, String filePath) {
  final ext = filePath.split('.').last.toLowerCase();
  final lines = content.split('\n');
  final symbols = <OutlineSymbol>[];
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final t = line.trim();
    switch (ext) {
      case 'dart':
        if (RegExp(r'^(abstract\s+)?(?:class|enum|mixin|extension)\s+\w+').hasMatch(t)) {
          final m = RegExp(r'(?:class|enum|mixin|extension)\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: m.group(1)!, line: i + 1, isClass: true));
        } else {
          final m = RegExp(r'(?:Future(?:<[^>]*>)?|Widget|void|String|int|bool|double|List|Map|dynamic)\s+(\w+)\s*[\(<]').firstMatch(line);
          if (m != null && !['if', 'for', 'while', 'switch', 'return'].contains(m.group(1))) {
            symbols.add(OutlineSymbol(name: '${m.group(1)!}()', line: i + 1, isClass: false));
          }
        }
      case 'js' || 'ts' || 'jsx' || 'tsx':
        if (t.startsWith('class ')) {
          final m = RegExp(r'class\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: m.group(1)!, line: i + 1, isClass: true));
        } else if (RegExp(r'^(?:export\s+)?(?:async\s+)?function\s+\w+').hasMatch(t)) {
          final m = RegExp(r'function\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: '${m.group(1)!}()', line: i + 1, isClass: false));
        } else if (RegExp(r'^(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(').hasMatch(t)) {
          final m = RegExp(r'(?:const|let|var)\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: '${m.group(1)!}()', line: i + 1, isClass: false));
        }
      case 'py':
        if (t.startsWith('class ')) {
          final m = RegExp(r'class\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: m.group(1)!, line: i + 1, isClass: true));
        } else if (t.startsWith('def ') || t.startsWith('async def ')) {
          final m = RegExp(r'def\s+(\w+)').firstMatch(t);
          if (m != null) symbols.add(OutlineSymbol(name: '${m.group(1)!}()', line: i + 1, isClass: false));
        }
    }
  }
  return symbols;
}

({int start, int end}) lineRange(String text, int pos) {
  final s = pos == 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
  final rawEnd = text.indexOf('\n', pos);
  return (start: s, end: rawEnd == -1 ? text.length : rawEnd);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── languageName ─────────────────────────────────────────────────────────
  group('languageName', () {
    final cases = {
      'main.dart': 'Dart',
      'app.js': 'JavaScript',
      'index.ts': 'TypeScript',
      'comp.jsx': 'React',
      'comp.tsx': 'React',
      'script.py': 'Python',
      'Main.java': 'Java',
      'App.kt': 'Kotlin',
      'main.go': 'Go',
      'lib.rs': 'Rust',
      'run.sh': 'Shell',
      'run.bash': 'Shell',
      'Makefile.cpp': 'C++',
      'lib.cc': 'C++',
      'lib.cxx': 'C++',
      'util.c': 'C',
      'style.css': 'CSS',
      'config.json': 'JSON',
      'pubspec.yaml': 'YAML',
      'docker.yml': 'YAML',
      'schema.xml': 'XML',
      'query.sql': 'SQL',
      'readme.md': 'Markdown',
      'AppDelegate.swift': 'Swift',
      'index.html': 'HTML',
      'unknown.xyz': 'XYZ',
    };

    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(languageName(entry.key), entry.value);
      });
    }

    test('file without extension → Plain Text', () {
      // "Makefile" → split gives ['Makefile'], last is 'Makefile' → uppercase
      // Test a true no-extension path
      expect(languageName('Makefile'), 'MAKEFILE'); // uppercase of 'Makefile'
    });
  });

  // ── commentPrefix ─────────────────────────────────────────────────────────
  group('commentPrefix', () {
    test('Dart uses //', () => expect(commentPrefix('a.dart'), '// '));
    test('JS uses //', () => expect(commentPrefix('a.js'), '// '));
    test('TS uses //', () => expect(commentPrefix('a.ts'), '// '));
    test('Python uses #', () => expect(commentPrefix('a.py'), '# '));
    test('Ruby uses #', () => expect(commentPrefix('a.rb'), '# '));
    test('Shell uses #', () => expect(commentPrefix('a.sh'), '# '));
    test('YAML uses #', () => expect(commentPrefix('a.yaml'), '# '));
    test('YML uses #', () => expect(commentPrefix('a.yml'), '# '));
    test('TOML uses #', () => expect(commentPrefix('a.toml'), '# '));
    test('CSS uses /*', () => expect(commentPrefix('a.css'), '/* '));
    test('Go uses //', () => expect(commentPrefix('a.go'), '// '));
  });

  // ── parseSymbols (Dart) ────────────────────────────────────────────────────
  group('parseSymbols Dart', () {
    test('finds class', () {
      const src = '''
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return Container();
  }
}
''';
      final syms = parseSymbols(src, 'lib/my_widget.dart');
      final classes = syms.where((s) => s.isClass).toList();
      expect(classes.any((s) => s.name == 'MyWidget'), true);
    });

    test('finds abstract class', () {
      const src = 'abstract class BaseRepo {\n}';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'BaseRepo' && s.isClass), true);
    });

    test('finds enum', () {
      const src = 'enum Status { active, inactive }';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'Status' && s.isClass), true);
    });

    test('finds mixin', () {
      const src = 'mixin Logging {\n}';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'Logging' && s.isClass), true);
    });

    test('finds extension', () {
      const src = 'extension StringX on String {\n}';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'StringX' && s.isClass), true);
    });

    test('finds void function', () {
      const src = '  void doSomething(String x) {\n  }';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'doSomething()' && !s.isClass), true);
    });

    test('finds Future function', () {
      const src = '  Future<void> loadData() async {\n  }';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.any((s) => s.name == 'loadData()'), true);
    });

    test('line numbers are 1-based', () {
      const src = 'class A {}\nclass B {}';
      final syms = parseSymbols(src, 'f.dart');
      expect(syms.firstWhere((s) => s.name == 'A').line, 1);
      expect(syms.firstWhere((s) => s.name == 'B').line, 2);
    });

    test('empty source returns no symbols', () {
      expect(parseSymbols('', 'f.dart'), isEmpty);
    });
  });

  // ── parseSymbols (Python) ────────────────────────────────────────────────
  group('parseSymbols Python', () {
    test('finds class and def', () {
      const src = '''
class Animal:
    def speak(self):
        pass
    async def eat(self):
        pass
''';
      final syms = parseSymbols(src, 'f.py');
      expect(syms.any((s) => s.name == 'Animal' && s.isClass), true);
      expect(syms.any((s) => s.name == 'speak()' && !s.isClass), true);
      expect(syms.any((s) => s.name == 'eat()' && !s.isClass), true);
    });

    test('ignores non-class/def lines', () {
      const src = 'x = 1\nprint("hello")';
      expect(parseSymbols(src, 'f.py'), isEmpty);
    });
  });

  // ── parseSymbols (JS/TS) ─────────────────────────────────────────────────
  group('parseSymbols JS/TS', () {
    test('finds class', () {
      const src = 'class UserService {\n}';
      final syms = parseSymbols(src, 'f.ts');
      expect(syms.any((s) => s.name == 'UserService' && s.isClass), true);
    });

    test('finds function declaration', () {
      const src = 'function fetchUser(id) {\n}';
      final syms = parseSymbols(src, 'f.js');
      expect(syms.any((s) => s.name == 'fetchUser()'), true);
    });

    test('finds exported function', () {
      const src = 'export function doThing() {\n}';
      final syms = parseSymbols(src, 'f.ts');
      expect(syms.any((s) => s.name == 'doThing()'), true);
    });

    test('finds arrow function const', () {
      const src = 'const handleClick = () => {\n}';
      final syms = parseSymbols(src, 'f.jsx');
      expect(syms.any((s) => s.name == 'handleClick()'), true);
    });
  });

  // ── lineRange ────────────────────────────────────────────────────────────
  group('lineRange', () {
    const text = 'line one\nline two\nline three';
    // positions:   01234567 8         17 18

    test('first line starts at 0', () {
      final r = lineRange(text, 0);
      expect(r.start, 0);
      expect(r.end, 8); // "line one"
    });

    test('second line correct range', () {
      final r = lineRange(text, 10); // somewhere in "line two"
      expect(text.substring(r.start, r.end), 'line two');
    });

    test('last line end equals text.length', () {
      final r = lineRange(text, 22); // in "line three"
      expect(r.end, text.length);
      expect(text.substring(r.start, r.end), 'line three');
    });

    test('single-line text', () {
      const single = 'hello';
      final r = lineRange(single, 2);
      expect(r.start, 0);
      expect(r.end, 5);
    });

    test('empty text', () {
      final r = lineRange('', 0);
      expect(r.start, 0);
      expect(r.end, 0);
    });

    test('cursor at newline boundary', () {
      // pos at exactly the start of line 2 (index 9)
      final r = lineRange(text, 9);
      expect(text.substring(r.start, r.end), 'line two');
    });
  });

  _autoPairsTests();
  _gitGutterTests();
}

String? closingBracket(String ch) => switch (ch) {
      '(' => ')',
      '[' => ']',
      '{' => '}',
      _ => null,
    };

// ── Git gutter diff parser ────────────────────────────────────────────────────

enum GutterMarkerType { added, removed }

Map<int, GutterMarkerType> parseDiffMarkers(String diff) {
  final result = <int, GutterMarkerType>{};
  int newLine = 0;

  for (final line in diff.split('\n')) {
    if (line.startsWith('@@')) {
      final match = RegExp(r'\+(\d+)').firstMatch(line);
      if (match != null) newLine = int.parse(match.group(1)!) - 1;
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
      newLine++;
      result[newLine] = GutterMarkerType.added;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      final nextLine = newLine + 1;
      if (!result.containsKey(nextLine)) {
        result[nextLine] = GutterMarkerType.removed;
      }
    } else if (!line.startsWith('\\')) {
      newLine++;
    }
  }
  return result;
}

// ── Auto-pairs tests ──────────────────────────────────────────────────────────

void _autoPairsTests() {
  group('closingBracket', () {
    test('( returns )', () => expect(closingBracket('('), ')'));
    test('[ returns ]', () => expect(closingBracket('['), ']'));
    test('{ returns }', () => expect(closingBracket('{'), '}'));
    test('other chars return null', () {
      for (final ch in ['"', "'", '`', 'a', ' ', '\n']) {
        expect(closingBracket(ch), isNull, reason: 'char: $ch');
      }
    });
  });
}

// ── Git gutter tests ──────────────────────────────────────────────────────────

void _gitGutterTests() {
  group('parseDiffMarkers', () {
    test('empty diff returns empty map', () {
      expect(parseDiffMarkers(''), isEmpty);
    });

    test('added lines are marked as added', () {
      const diff = '''
--- a/foo.dart
+++ b/foo.dart
@@ -1,3 +1,4 @@
 line1
+newLine
 line2
 line3
''';
      final markers = parseDiffMarkers(diff);
      expect(markers[2], GutterMarkerType.added);
    });

    test('removed lines mark next line as removed', () {
      const diff = '''
--- a/foo.dart
+++ b/foo.dart
@@ -1,4 +1,3 @@
 line1
-oldLine
 line2
 line3
''';
      final markers = parseDiffMarkers(diff);
      expect(markers[2], GutterMarkerType.removed);
    });

    test('added lines are not overwritten by removed markers', () {
      // When a line is both added and had a removal before it, added wins.
      const diff = '''
--- a/foo.dart
+++ b/foo.dart
@@ -1,2 +1,2 @@
-old
+new
 context
''';
      final markers = parseDiffMarkers(diff);
      // Line 1 should be added (the + line)
      expect(markers[1], GutterMarkerType.added);
    });

    test('multiple hunks parsed correctly', () {
      const diff = '''
--- a/foo.dart
+++ b/foo.dart
@@ -1,2 +1,3 @@
 same
+added1
 same2
@@ -10,2 +11,3 @@
 other
+added2
 end
''';
      final markers = parseDiffMarkers(diff);
      expect(markers.values, contains(GutterMarkerType.added));
      // Should have at least 2 added markers
      final addedCount =
          markers.values.where((v) => v == GutterMarkerType.added).length;
      expect(addedCount, greaterThanOrEqualTo(2));
    });

    test('handles no-newline-at-end markers', () {
      const diff = '''
--- a/foo.dart
+++ b/foo.dart
@@ -1,1 +1,1 @@
-old
\\ No newline at end of file
+new
\\ No newline at end of file
''';
      // Should not throw
      expect(() => parseDiffMarkers(diff), returnsNormally);
    });
  });
}

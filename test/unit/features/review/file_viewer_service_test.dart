import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/review/data/file_viewer_service.dart';

void main() {
  const service = FileViewerService.instance;

  group('FileViewerService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_viewer_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns success result for readable file', () async {
      final file = File('${tempDir.path}/hello.dart');
      await file.writeAsString('void main() => print("hello");');

      final result = await service.readFile(file.path);

      expect(result.isSuccess, isTrue);
      expect(result.content, contains('void main()'));
      expect(result.language, 'dart');
    });

    test('returns error for non-existent file', () async {
      final result = await service.readFile('${tempDir.path}/nonexistent.txt');

      expect(result.isSuccess, isFalse);
      expect(result.error, contains('not found'));
    });

    test('detects language from extension correctly', () async {
      final cases = {
        'file.dart': 'dart',
        'file.js': 'javascript',
        'file.ts': 'typescript',
        'file.py': 'python',
        'file.rs': 'rust',
        'file.go': 'go',
        'file.yaml': 'yaml',
        'file.json': 'json',
        'file.md': 'markdown',
        'file.sh': 'bash',
        'file.unknown': 'plaintext',
      };

      for (final entry in cases.entries) {
        final file = File('${tempDir.path}/${entry.key}');
        await file.writeAsString('content');
        final result = await service.readFile(file.path);
        expect(result.language, entry.value, reason: 'for ${entry.key}');
      }
    });

    test('reads multi-line file content correctly', () async {
      const content = 'line 1\nline 2\nline 3';
      final file = File('${tempDir.path}/multi.txt');
      await file.writeAsString(content);

      final result = await service.readFile(file.path);

      expect(result.content, content);
    });
  });
}

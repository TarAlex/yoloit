import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/review/models/review_models.dart';

void main() {
  group('FileChange', () {
    const change = FileChange(
      path: 'lib/main.dart',
      status: FileChangeStatus.modified,
      isStaged: false,
      addedLines: 10,
      removedLines: 5,
    );

    test('fileName returns last path segment', () {
      expect(change.fileName, 'main.dart');
      expect(
        const FileChange(path: 'a/b/c/foo.txt', status: FileChangeStatus.added).fileName,
        'foo.txt',
      );
    });

    test('copyWith updates only specified fields', () {
      final staged = change.copyWith(isStaged: true);
      expect(staged.isStaged, true);
      expect(staged.path, change.path);
      expect(staged.addedLines, change.addedLines);
    });

    test('equality is value-based', () {
      const same = FileChange(
        path: 'lib/main.dart',
        status: FileChangeStatus.modified,
        isStaged: false,
        addedLines: 10,
        removedLines: 5,
      );
      expect(change, same);
    });

    test('different status gives not equal', () {
      const other = FileChange(path: 'lib/main.dart', status: FileChangeStatus.added);
      expect(change, isNot(equals(other)));
    });
  });

  group('DiffHunk', () {
    const line1 = DiffLine(type: DiffLineType.context, content: 'ctx', oldLineNum: 1, newLineNum: 1);
    const line2 = DiffLine(type: DiffLineType.add, content: 'new', newLineNum: 2);
    const hunk = DiffHunk(header: '@@ -1,1 +1,2 @@', lines: [line1, line2], oldStart: 1, newStart: 1);

    test('hunk contains correct lines', () {
      expect(hunk.lines, hasLength(2));
      expect(hunk.lines[0].type, DiffLineType.context);
      expect(hunk.lines[1].type, DiffLineType.add);
    });

    test('equality is value-based', () {
      const same = DiffHunk(
        header: '@@ -1,1 +1,2 @@',
        lines: [line1, line2],
        oldStart: 1,
        newStart: 1,
      );
      expect(hunk, same);
    });
  });

  group('FileTreeNode', () {
    const dirNode = FileTreeNode(
      name: 'src',
      path: '/project/src',
      isDirectory: true,
    );

    const fileNode = FileTreeNode(
      name: 'main.dart',
      path: '/project/src/main.dart',
      isDirectory: false,
    );

    test('directory node defaults to collapsed', () {
      expect(dirNode.isExpanded, false);
    });

    test('copyWith toggles isExpanded', () {
      final expanded = dirNode.copyWith(isExpanded: true);
      expect(expanded.isExpanded, true);
      expect(expanded.name, dirNode.name);
    });

    test('file node is not a directory', () {
      expect(fileNode.isDirectory, false);
    });

    test('copyWith adds children', () {
      final withChildren = dirNode.copyWith(isExpanded: true, children: [fileNode]);
      expect(withChildren.children, hasLength(1));
      expect(withChildren.children.first.name, 'main.dart');
    });
  });
}

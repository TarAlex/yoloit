import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/review/models/review_models.dart';

void main() {
  group('EditorTab', () {
    const path = '/workspace/lib/main.dart';

    test('default values are correct', () {
      const tab = EditorTab(filePath: path);
      expect(tab.filePath, path);
      expect(tab.content, isNull);
      expect(tab.originalContent, isNull);
      expect(tab.isLoading, false);
      expect(tab.error, isNull);
      expect(tab.diffHunks, isNull);
      expect(tab.workspacePath, isNull);
    });

    test('fileName extracts last path segment', () {
      expect(const EditorTab(filePath: '/a/b/c/main.dart').fileName, 'main.dart');
      expect(const EditorTab(filePath: 'plain.txt').fileName, 'plain.txt');
      expect(const EditorTab(filePath: '/folder/').fileName, '');
    });

    group('isDirty', () {
      test('false when content is null', () {
        const tab = EditorTab(filePath: path);
        expect(tab.isDirty, false);
      });

      test('false when content matches originalContent', () {
        const tab = EditorTab(filePath: path, content: 'hello', originalContent: 'hello');
        expect(tab.isDirty, false);
      });

      test('true when content differs from originalContent', () {
        const tab = EditorTab(filePath: path, content: 'changed', originalContent: 'original');
        expect(tab.isDirty, true);
      });

      test('true when originalContent is null but content is set', () {
        const tab = EditorTab(filePath: path, content: 'hello');
        expect(tab.isDirty, true);
      });
    });

    group('isDiff', () {
      test('false when diffHunks is null', () {
        const tab = EditorTab(filePath: 'diff:/some/file.dart');
        expect(tab.isDiff, false);
      });

      test('true when diffHunks is set (even empty list)', () {
        final tab = EditorTab(filePath: 'diff:/some/file.dart', diffHunks: const []);
        expect(tab.isDiff, true);
      });

      test('true when diffHunks has content', () {
        final tab = EditorTab(
          filePath: 'diff:/f.dart',
          diffHunks: [
            DiffHunk(
              header: '@@ -1 +1 @@',
              lines: const [DiffLine(type: DiffLineType.add, content: '+ foo')],
              oldStart: 1,
              newStart: 1,
            ),
          ],
        );
        expect(tab.isDiff, true);
      });
    });

    group('copyWith', () {
      const base = EditorTab(filePath: path, content: 'old', originalContent: 'old', isLoading: false);

      test('updates content', () {
        final t = base.copyWith(content: 'new');
        expect(t.content, 'new');
        expect(t.filePath, path);
        expect(t.originalContent, 'old');
      });

      test('updates isLoading', () {
        final t = base.copyWith(isLoading: true);
        expect(t.isLoading, true);
        expect(t.content, 'old');
      });

      test('updates error', () {
        final t = base.copyWith(error: 'oops');
        expect(t.error, 'oops');
      });

      test('preserves diffHunks and workspacePath through copyWith', () {
        final tab = EditorTab(
          filePath: path,
          diffHunks: const [],
          workspacePath: '/ws',
        );
        final copy = tab.copyWith(isLoading: false);
        expect(copy.diffHunks, const []);
        expect(copy.workspacePath, '/ws');
      });
    });

    group('Equatable', () {
      test('equal when all props match', () {
        const a = EditorTab(filePath: path, content: 'x', originalContent: 'x');
        const b = EditorTab(filePath: path, content: 'x', originalContent: 'x');
        expect(a, equals(b));
      });

      test('not equal when content differs', () {
        const a = EditorTab(filePath: path, content: 'x');
        const b = EditorTab(filePath: path, content: 'y');
        expect(a, isNot(equals(b)));
      });
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  group('FileEditorState', () {
    const path1 = '/w/lib/a.dart';
    const path2 = '/w/lib/b.dart';

    test('initial state is empty and hidden', () {
      const s = FileEditorState();
      expect(s.tabs, isEmpty);
      expect(s.activeIndex, 0);
      expect(s.isVisible, false);
      expect(s.isOpen, false);
      expect(s.activeTab, isNull);
    });

    group('activeTab', () {
      test('returns tab at activeIndex', () {
        final tabs = [
          const EditorTab(filePath: path1),
          const EditorTab(filePath: path2),
        ];
        final s = FileEditorState(tabs: tabs, activeIndex: 1);
        expect(s.activeTab?.filePath, path2);
      });

      test('clamps out-of-bounds activeIndex', () {
        final tabs = [const EditorTab(filePath: path1)];
        final s = FileEditorState(tabs: tabs, activeIndex: 99);
        expect(s.activeTab?.filePath, path1);
      });

      test('null when tabs empty', () {
        const s = FileEditorState();
        expect(s.activeTab, isNull);
      });
    });

    group('convenience getters', () {
      final tab = const EditorTab(filePath: path1, content: 'new', originalContent: 'old');

      test('isDirty delegates to activeTab', () {
        final s = FileEditorState(tabs: [tab], activeIndex: 0);
        expect(s.isDirty, true);
      });

      test('filePath returns active file path', () {
        final s = FileEditorState(tabs: [tab]);
        expect(s.filePath, path1);
      });

      test('content returns active content', () {
        final s = FileEditorState(tabs: [tab]);
        expect(s.content, 'new');
      });

      test('fileName returns active file name', () {
        final s = FileEditorState(tabs: [tab]);
        expect(s.fileName, 'a.dart');
      });

      test('fileName empty when no tabs', () {
        const s = FileEditorState();
        expect(s.fileName, '');
      });
    });

    group('copyWith', () {
      test('adds tabs', () {
        const s = FileEditorState();
        final s2 = s.copyWith(tabs: [const EditorTab(filePath: path1)]);
        expect(s2.tabs.length, 1);
        expect(s2.isVisible, false);
      });

      test('updates isVisible', () {
        const s = FileEditorState();
        expect(s.copyWith(isVisible: true).isVisible, true);
      });

      test('updates activeIndex', () {
        final s = FileEditorState(
          tabs: [const EditorTab(filePath: path1), const EditorTab(filePath: path2)],
        );
        expect(s.copyWith(activeIndex: 1).activeIndex, 1);
      });
    });

    group('Equatable', () {
      test('equal states are equal', () {
        const a = FileEditorState(tabs: [], activeIndex: 0, isVisible: false);
        const b = FileEditorState(tabs: [], activeIndex: 0, isVisible: false);
        expect(a, equals(b));
      });

      test('states with different tabs are not equal', () {
        final a = FileEditorState(tabs: [const EditorTab(filePath: path1)]);
        final b = FileEditorState(tabs: [const EditorTab(filePath: path2)]);
        expect(a, isNot(equals(b)));
      });
    });
  });
}

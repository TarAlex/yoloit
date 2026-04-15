import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmpDir = await Directory.systemTemp.createTemp('editor_test_');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<File> writeFile(String name, String content) async {
    final f = File('${tmpDir.path}/$name');
    await f.writeAsString(content);
    return f;
  }

  // ── Initial state ────────────────────────────────────────────────────────────
  group('FileEditorCubit initial state', () {
    test('starts empty and hidden', () {
      final cubit = FileEditorCubit();
      expect(cubit.state, equals(const FileEditorState()));
      expect(cubit.state.tabs, isEmpty);
      expect(cubit.state.isVisible, false);
      cubit.close();
    });
  });

  // ── setWorkspace ────────────────────────────────────────────────────────────
  group('setWorkspace', () {
    test(
      'restores saved tabs, emits placeholders first, and keeps active index',
      () async {
        final a = await writeFile('a.dart', 'class A {}');
        final b = await writeFile('b.dart', 'class B {}');
        SharedPreferences.setMockInitialValues({
          'editor.tabs.ws-1': [a.path, b.path],
          'editor.active.ws-1': 1,
        });

        final cubit = FileEditorCubit();
        final emitted = <FileEditorState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(() async {
          await sub.cancel();
          await cubit.close();
        });

        await cubit.setWorkspace('ws-1');
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isNotEmpty);
        expect(emitted.first.isVisible, true);
        expect(emitted.first.activeIndex, 1);
        expect(emitted.first.tabs, hasLength(2));
        expect(emitted.first.tabs.every((tab) => tab.isLoading), true);

        expect(cubit.state.isVisible, true);
        expect(cubit.state.activeIndex, 1);
        expect(cubit.state.tabs, hasLength(2));
        expect(cubit.state.tabs[0].content, 'class A {}');
        expect(cubit.state.tabs[1].content, 'class B {}');
        expect(cubit.state.tabs.every((tab) => !tab.isLoading), true);
      },
    );

    test(
      'filters out missing files and hides panel when nothing can be restored',
      () async {
        SharedPreferences.setMockInitialValues({
          'editor.tabs.ws-2': ['/missing/a.dart', '/missing/b.dart'],
          'editor.active.ws-2': 1,
        });

        final cubit = FileEditorCubit();
        addTearDown(cubit.close);

        await cubit.setWorkspace('ws-2');

        expect(cubit.state.tabs, isEmpty);
        expect(cubit.state.activeIndex, 0);
        expect(cubit.state.isVisible, false);
      },
    );
  });

  // ── openFile ────────────────────────────────────────────────────────────────
  group('openFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'loads file content and shows panel',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await writeFile('hello.dart', 'void main() {}');
        await cubit.openFile(file.path);
      },
      verify: (cubit) {
        final s = cubit.state;
        expect(s.isVisible, true);
        expect(s.tabs.length, 1);
        expect(s.activeTab?.content, 'void main() {}');
        expect(s.activeTab?.isLoading, false);
        expect(s.activeTab?.error, isNull);
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'switches to existing tab without duplicating',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await writeFile('a.dart', 'a');
        await cubit.openFile(file.path);
        await cubit.openFile(file.path); // second open
      },
      verify: (cubit) {
        expect(cubit.state.tabs.length, 1);
        expect(cubit.state.activeIndex, 0);
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'opens multiple files as separate tabs',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final a = await writeFile('a.dart', 'A');
        final b = await writeFile('b.dart', 'B');
        await cubit.openFile(a.path);
        await cubit.openFile(b.path);
      },
      verify: (cubit) {
        expect(cubit.state.tabs.length, 2);
        expect(cubit.state.activeIndex, 1);
        expect(cubit.state.tabs[0].content, 'A');
        expect(cubit.state.tabs[1].content, 'B');
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'emits error tab when file does not exist',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        await cubit.openFile('/nonexistent/path/file.dart');
      },
      verify: (cubit) {
        final tab = cubit.state.activeTab;
        expect(tab, isNotNull);
        expect(tab!.error, isNotNull);
        expect(tab.isLoading, false);
      },
    );
  });

  // ── updateContent / auto-save ────────────────────────────────────────────────
  group('updateContent', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'updates content in active tab',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await writeFile('f.dart', 'original');
        await cubit.openFile(file.path);
        cubit.updateContent('modified');
      },
      verify: (cubit) {
        expect(cubit.state.activeTab?.content, 'modified');
        expect(cubit.state.activeTab?.isDirty, true);
      },
    );

    test('does nothing when no tab is open', () {
      final cubit = FileEditorCubit();
      expect(() => cubit.updateContent('x'), returnsNormally);
      expect(cubit.state.tabs, isEmpty);
      cubit.close();
    });

    blocTest<FileEditorCubit, FileEditorState>(
      'updateContent marks tab as dirty before auto-save fires',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await writeFile('f.dart', 'original');
        await cubit.openFile(file.path);
        cubit.updateContent('auto-saved');
        // verify dirty immediately — auto-save hasn't fired yet
      },
      verify: (cubit) {
        expect(cubit.state.activeTab?.content, 'auto-saved');
        expect(cubit.state.activeTab?.isDirty, true);
      },
    );

    test('auto-save writes to disk after 800ms delay', () async {
      final dir = await Directory.systemTemp.createTemp('autosave_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/f.dart');
      await file.writeAsString('original');

      final cubit = FileEditorCubit();
      await cubit.openFile(file.path);
      cubit.updateContent('auto-saved-content');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      final diskContent = await file.readAsString();
      expect(diskContent, 'auto-saved-content');
      await cubit.close();
    });

    test('ignores updates while the active tab is still loading', () async {
      final file = await writeFile('loading.dart', 'original');
      final cubit = FileEditorCubit()
        ..emit(
          FileEditorState(
            isVisible: true,
            tabs: [EditorTab(filePath: file.path, isLoading: true)],
          ),
        );
      addTearDown(cubit.close);

      cubit.updateContent('');
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      expect(cubit.state.activeTab?.content, isNull);
      expect(await file.readAsString(), 'original');
    });

    test(
      'auto-save can intentionally clear a loaded file to empty content',
      () async {
        final file = await writeFile('clear-me.dart', 'original');
        final cubit = FileEditorCubit();
        addTearDown(cubit.close);

        await cubit.openFile(file.path);
        cubit.updateContent('');
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        expect(await file.readAsString(), '');
        expect(cubit.state.activeTab?.content, '');
        expect(cubit.state.activeTab?.originalContent, '');
        expect(cubit.state.activeTab?.isDirty, false);
      },
    );
  });

  // ── saveFile ─────────────────────────────────────────────────────────────────
  group('saveFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'writes content to disk immediately',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await writeFile('save.dart', 'original');
        await cubit.openFile(file.path);
        cubit.updateContent('updated');
        await cubit.saveFile();
      },
      verify: (cubit) async {
        final path = cubit.state.tabs.first.filePath;
        expect(await File(path).readAsString(), 'updated');
        expect(cubit.state.activeTab?.isDirty, false);
      },
    );

    test('does nothing when no tabs', () async {
      final cubit = FileEditorCubit();
      await expectLater(cubit.saveFile(), completes);
      cubit.close();
    });

    test('allows clearing a loaded file to empty content', () async {
      final file = await writeFile('clear-on-save.dart', 'original');
      final cubit = FileEditorCubit();
      addTearDown(cubit.close);

      await cubit.openFile(file.path);
      cubit.updateContent('');
      await cubit.saveFile();

      expect(await file.readAsString(), '');
      expect(cubit.state.activeTab?.originalContent, '');
      expect(cubit.state.activeTab?.isDirty, false);
    });
  });

  // ── reloadActiveIfUnchanged ─────────────────────────────────────────────────
  group('reloadActiveIfUnchanged', () {
    test(
      'reloads the active file from disk when it has no local changes',
      () async {
        final file = await writeFile('reload.dart', 'before');
        final cubit = FileEditorCubit();
        addTearDown(cubit.close);

        await cubit.openFile(file.path);
        await file.writeAsString('after');

        await cubit.reloadActiveIfUnchanged();

        expect(cubit.state.activeTab?.content, 'after');
        expect(cubit.state.activeTab?.originalContent, 'after');
        expect(cubit.state.activeTab?.isDirty, false);
      },
    );

    test('keeps local content when the active file is dirty', () async {
      final file = await writeFile('dirty.dart', 'before');
      final cubit = FileEditorCubit();
      addTearDown(cubit.close);

      await cubit.openFile(file.path);
      cubit.updateContent('local change');
      await file.writeAsString('external change');

      await cubit.reloadActiveIfUnchanged();

      expect(cubit.state.activeTab?.content, 'local change');
      expect(cubit.state.activeTab?.originalContent, 'before');
      expect(cubit.state.activeTab?.isDirty, true);
    });
  });

  // ── closeTab ─────────────────────────────────────────────────────────────────
  group('closeTab', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'removes tab and hides panel when last tab closed',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final f = await writeFile('a.dart', 'a');
        await cubit.openFile(f.path);
        cubit.closeTab(0);
      },
      verify: (cubit) {
        expect(cubit.state.tabs, isEmpty);
        expect(cubit.state.isVisible, false);
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'closes tab at index and adjusts activeIndex',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final a = await writeFile('a.dart', 'a');
        final b = await writeFile('b.dart', 'b');
        await cubit.openFile(a.path);
        await cubit.openFile(b.path);
        cubit.closeTab(0); // close first
      },
      verify: (cubit) {
        expect(cubit.state.tabs.length, 1);
        expect(cubit.state.tabs.first.content, 'b');
        expect(cubit.state.activeIndex, 0);
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'out-of-bounds index is ignored',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final f = await writeFile('a.dart', 'a');
        await cubit.openFile(f.path);
        cubit.closeTab(99);
      },
      verify: (cubit) {
        expect(cubit.state.tabs.length, 1);
      },
    );
  });

  // ── switchTab ────────────────────────────────────────────────────────────────
  group('switchTab', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'changes activeIndex',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final a = await writeFile('a.dart', 'a');
        final b = await writeFile('b.dart', 'b');
        await cubit.openFile(a.path);
        await cubit.openFile(b.path);
        cubit.switchTab(0);
      },
      verify: (cubit) {
        expect(cubit.state.activeIndex, 0);
        expect(cubit.state.activeTab?.content, 'a');
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'ignores invalid index',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final f = await writeFile('a.dart', 'a');
        await cubit.openFile(f.path);
        cubit.switchTab(-1);
        cubit.switchTab(99);
      },
      verify: (cubit) {
        expect(cubit.state.activeIndex, 0);
      },
    );
  });

  // ── panel visibility ─────────────────────────────────────────────────────────
  group('panel visibility', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'showPanel sets isVisible true',
      build: () => FileEditorCubit(),
      act: (cubit) => cubit.showPanel(),
      verify: (cubit) => expect(cubit.state.isVisible, true),
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'hidePanel sets isVisible false',
      build: () => FileEditorCubit(),
      seed: () => const FileEditorState(isVisible: true),
      act: (cubit) => cubit.hidePanel(),
      verify: (cubit) => expect(cubit.state.isVisible, false),
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'togglePanel flips isVisible',
      build: () => FileEditorCubit(),
      seed: () => const FileEditorState(isVisible: false),
      act: (cubit) {
        cubit.togglePanel();
        cubit.togglePanel();
      },
      verify: (cubit) => expect(cubit.state.isVisible, false),
    );
  });

  // ── openDiff ─────────────────────────────────────────────────────────────────
  group('openDiff', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'opens diff tab with diff: prefix',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        // Use an actual git repo (the project itself)
        await cubit.openDiff('lib/main.dart', Directory.current.path);
      },
      verify: (cubit) {
        final tab = cubit.state.activeTab;
        expect(tab, isNotNull);
        expect(tab!.filePath, startsWith('diff:'));
        expect(tab.isLoading, false);
        expect(cubit.state.isVisible, true);
      },
    );

    blocTest<FileEditorCubit, FileEditorState>(
      'switches to existing diff tab without duplicating',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        await cubit.openDiff('lib/main.dart', Directory.current.path);
        await cubit.openDiff('lib/main.dart', Directory.current.path);
      },
      verify: (cubit) {
        expect(
          cubit.state.tabs
              .where((t) => t.filePath == 'diff:lib/main.dart')
              .length,
          1,
        );
      },
    );
  });

  // ── closeFile ────────────────────────────────────────────────────────────────
  group('closeFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'closes active tab',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final a = await writeFile('a.dart', 'a');
        final b = await writeFile('b.dart', 'b');
        await cubit.openFile(a.path);
        await cubit.openFile(b.path);
        cubit.closeFile(); // closes b (active)
      },
      verify: (cubit) {
        expect(cubit.state.tabs.length, 1);
        expect(cubit.state.tabs.first.content, 'a');
      },
    );
  });
}

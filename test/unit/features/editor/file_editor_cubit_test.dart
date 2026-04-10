import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('editor_test_');
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<File> _write(String name, String content) async {
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

  // ── openFile ────────────────────────────────────────────────────────────────
  group('openFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'loads file content and shows panel',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await _write('hello.dart', 'void main() {}');
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
        final file = await _write('a.dart', 'a');
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
        final a = await _write('a.dart', 'A');
        final b = await _write('b.dart', 'B');
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
        final file = await _write('f.dart', 'original');
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
        final file = await _write('f.dart', 'original');
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
  });

  // ── saveFile ─────────────────────────────────────────────────────────────────
  group('saveFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'writes content to disk immediately',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final file = await _write('save.dart', 'original');
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
  });

  // ── closeTab ─────────────────────────────────────────────────────────────────
  group('closeTab', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'removes tab and hides panel when last tab closed',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final f = await _write('a.dart', 'a');
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
        final a = await _write('a.dart', 'a');
        final b = await _write('b.dart', 'b');
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
        final f = await _write('a.dart', 'a');
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
        final a = await _write('a.dart', 'a');
        final b = await _write('b.dart', 'b');
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
        final f = await _write('a.dart', 'a');
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
        expect(cubit.state.tabs.where((t) => t.filePath == 'diff:lib/main.dart').length, 1);
      },
    );
  });

  // ── closeFile ────────────────────────────────────────────────────────────────
  group('closeFile', () {
    blocTest<FileEditorCubit, FileEditorState>(
      'closes active tab',
      build: () => FileEditorCubit(),
      act: (cubit) async {
        final a = await _write('a.dart', 'a');
        final b = await _write('b.dart', 'b');
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

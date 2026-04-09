import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/editor/bloc/file_editor_state.dart';
import 'package:yoloit/features/review/data/diff_service.dart';

class FileEditorCubit extends Cubit<FileEditorState> {
  FileEditorCubit() : super(const FileEditorState());

  // Debounce timer per file path — auto-saves 800 ms after the last keystroke.
  final Map<String, Timer> _saveTimers = {};

  @override
  Future<void> close() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    return super.close();
  }

  /// Opens [absolutePath] in a new tab; switches to it if already open.
  Future<void> openFile(String absolutePath) async {
    final existingIndex =
        state.tabs.indexWhere((t) => t.filePath == absolutePath);
    if (existingIndex != -1) {
      emit(state.copyWith(activeIndex: existingIndex, isVisible: true));
      return;
    }

    final placeholder = EditorTab(filePath: absolutePath, isLoading: true);
    final newTabs = [...state.tabs, placeholder];
    final newIndex = newTabs.length - 1;
    emit(state.copyWith(tabs: newTabs, activeIndex: newIndex, isVisible: true));

    try {
      final content = await File(absolutePath).readAsString();
      _updateTab(
        absolutePath,
        (t) => EditorTab(
          filePath: absolutePath,
          content: content,
          originalContent: content,
        ),
      );
    } catch (e) {
      _updateTab(
        absolutePath,
        (t) => t.copyWith(isLoading: false, error: 'Cannot read file: $e'),
      );
    }
  }

  /// Called by CodeController on every keystroke — updates state and
  /// schedules a debounced auto-save (800 ms after last change).
  void updateContent(String content) {
    final tab = state.activeTab;
    if (tab == null) return;
    _updateTab(tab.filePath, (t) => t.copyWith(content: content));
    _scheduleAutoSave(tab.filePath, content);
  }

  /// Immediately saves [filePath] to disk and marks it clean.
  Future<void> saveFile() async {
    final tab = state.activeTab;
    if (tab == null || tab.content == null) return;
    await _writeToDisk(tab.filePath, tab.content!);
  }

  /// Closes the tab at [index].
  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final path = state.tabs[index].filePath;
    _saveTimers.remove(path)?.cancel();
    final newTabs = List<EditorTab>.from(state.tabs)..removeAt(index);
    if (newTabs.isEmpty) {
      emit(state.copyWith(tabs: newTabs, activeIndex: 0, isVisible: false));
      return;
    }
    final newActive = (state.activeIndex >= newTabs.length)
        ? newTabs.length - 1
        : state.activeIndex;
    emit(state.copyWith(tabs: newTabs, activeIndex: newActive));
  }

  void switchTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    emit(state.copyWith(activeIndex: index));
  }

  void closeFile() => closeTab(state.activeIndex);
  void togglePanel() => emit(state.copyWith(isVisible: !state.isVisible));
  void showPanel() => emit(state.copyWith(isVisible: true));
  void hidePanel() => emit(state.copyWith(isVisible: false));

  /// Opens a diff view for [filePath] (relative to [workspacePath]) in a new tab.
  Future<void> openDiff(String filePath, String workspacePath) async {
    final tabPath = 'diff:$filePath';
    final existing = state.tabs.indexWhere((t) => t.filePath == tabPath);
    if (existing != -1) {
      emit(state.copyWith(activeIndex: existing, isVisible: true));
      return;
    }

    final placeholder = EditorTab(filePath: tabPath, isLoading: true, workspacePath: workspacePath);
    final newTabs = [...state.tabs, placeholder];
    emit(state.copyWith(tabs: newTabs, activeIndex: newTabs.length - 1, isVisible: true));

    try {
      final hunks = await DiffService.instance.getDiff(workspacePath, filePath);
      _updateTab(
        tabPath,
        (_) => EditorTab(
          filePath: tabPath,
          workspacePath: workspacePath,
          diffHunks: hunks,
        ),
      );
    } catch (e) {
      _updateTab(tabPath, (t) => t.copyWith(isLoading: false, error: 'Cannot load diff: $e'));
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _scheduleAutoSave(String filePath, String content) {
    _saveTimers[filePath]?.cancel();
    _saveTimers[filePath] = Timer(
      const Duration(milliseconds: 800),
      () => _writeToDisk(filePath, content),
    );
  }

  Future<void> _writeToDisk(String filePath, String content) async {
    try {
      await File(filePath).writeAsString(content);
      _updateTab(filePath, (t) => t.copyWith(originalContent: content));
    } catch (_) {
      // Silently ignore write errors for auto-save.
    }
  }

  void _updateTab(String filePath, EditorTab Function(EditorTab) updater) {
    final idx = state.tabs.indexWhere((t) => t.filePath == filePath);
    if (idx == -1) return;
    final newTabs = List<EditorTab>.from(state.tabs);
    newTabs[idx] = updater(newTabs[idx]);
    emit(state.copyWith(tabs: newTabs));
  }
}

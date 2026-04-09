import 'package:equatable/equatable.dart';
import 'package:yoloit/features/review/models/review_models.dart';

/// A single open file tab.
class EditorTab extends Equatable {
  const EditorTab({
    required this.filePath,
    this.content,
    this.originalContent,
    this.isLoading = false,
    this.error,
    this.diffHunks,
    this.workspacePath,
  });

  final String filePath;
  final String? content;
  final String? originalContent;
  final bool isLoading;
  final String? error;
  final List<DiffHunk>? diffHunks;
  final String? workspacePath;

  bool get isDirty => content != null && content != originalContent;
  bool get isDiff => diffHunks != null;
  String get fileName => filePath.split('/').last;

  EditorTab copyWith({
    String? content,
    String? originalContent,
    bool? isLoading,
    String? error,
  }) {
    return EditorTab(
      filePath: filePath,
      content: content ?? this.content,
      originalContent: originalContent ?? this.originalContent,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      diffHunks: diffHunks,
      workspacePath: workspacePath,
    );
  }

  @override
  List<Object?> get props => [filePath, content, originalContent, isLoading, error, diffHunks, workspacePath];
}

class FileEditorState extends Equatable {
  const FileEditorState({
    this.tabs = const [],
    this.activeIndex = 0,
    this.isVisible = false,
  });

  final List<EditorTab> tabs;
  final int activeIndex;

  /// Whether the editor panel is visible (panel toggle).
  final bool isVisible;

  bool get isOpen => tabs.isNotEmpty;

  EditorTab? get activeTab =>
      tabs.isEmpty ? null : tabs[activeIndex.clamp(0, tabs.length - 1)];

  /// Convenience getters for backward-compat call sites.
  bool get isDirty => activeTab?.isDirty ?? false;
  String? get filePath => activeTab?.filePath;
  String? get content => activeTab?.content;
  String get fileName => activeTab?.fileName ?? '';

  FileEditorState copyWith({
    List<EditorTab>? tabs,
    int? activeIndex,
    bool? isVisible,
  }) {
    return FileEditorState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  List<Object?> get props => [tabs, activeIndex, isVisible];
}

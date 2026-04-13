import 'package:equatable/equatable.dart';

enum DiffLineType { add, remove, context, header }

enum FileChangeStatus { modified, added, deleted, renamed, untracked }

enum PrCheckStatus { passed, failed, running }

class DiffLine extends Equatable {
  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNum,
    this.newLineNum,
  });

  final DiffLineType type;
  final String content;
  final int? oldLineNum;
  final int? newLineNum;

  @override
  List<Object?> get props => [type, content, oldLineNum, newLineNum];
}

class DiffHunk extends Equatable {
  const DiffHunk({
    required this.header,
    required this.lines,
    required this.oldStart,
    required this.newStart,
  });

  final String header;
  final List<DiffLine> lines;
  final int oldStart;
  final int newStart;

  @override
  List<Object?> get props => [header, lines, oldStart, newStart];
}

class FileChange extends Equatable {
  const FileChange({
    required this.path,
    required this.status,
    this.isStaged = false,
    this.addedLines = 0,
    this.removedLines = 0,
    this.repoPath,
  });

  final String path;
  final FileChangeStatus status;
  final bool isStaged;
  final int addedLines;
  final int removedLines;
  /// Absolute path of the git repository root this file belongs to.
  final String? repoPath;

  String get fileName => path.split('/').last;
  String get repoName => repoPath != null ? repoPath!.split('/').last : '';

  FileChange copyWith({
    FileChangeStatus? status,
    bool? isStaged,
    int? addedLines,
    int? removedLines,
    String? repoPath,
  }) {
    return FileChange(
      path: path,
      status: status ?? this.status,
      isStaged: isStaged ?? this.isStaged,
      addedLines: addedLines ?? this.addedLines,
      removedLines: removedLines ?? this.removedLines,
      repoPath: repoPath ?? this.repoPath,
    );
  }

  @override
  List<Object?> get props => [path, status, isStaged, addedLines, removedLines, repoPath];
}

class PrCheck extends Equatable {
  const PrCheck({required this.name, required this.status});
  final String name;
  final PrCheckStatus status;

  @override
  List<Object?> get props => [name, status];
}

class PrStatus extends Equatable {
  const PrStatus({
    required this.title,
    required this.prNumber,
    required this.status,
    required this.checks,
    required this.reviewers,
  });

  final String title;
  final int prNumber;
  final String status;
  final List<PrCheck> checks;
  final int reviewers;

  @override
  List<Object?> get props => [title, prNumber, status, checks, reviewers];
}

class FileTreeNode extends Equatable {
  const FileTreeNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children = const [],
    this.isExpanded = false,
    this.isModified = false,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final List<FileTreeNode> children;
  final bool isExpanded;
  final bool isModified;

  FileTreeNode copyWith({
    List<FileTreeNode>? children,
    bool? isExpanded,
    bool? isModified,
  }) {
    return FileTreeNode(
      name: name,
      path: path,
      isDirectory: isDirectory,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
      isModified: isModified ?? this.isModified,
    );
  }

  @override
  List<Object?> get props => [name, path, isDirectory, children, isExpanded, isModified];
}

import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:yoloit/core/services/git_service.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/data/diff_service.dart';
import 'package:yoloit/features/review/data/file_viewer_service.dart';
import 'package:yoloit/features/review/models/review_models.dart';

class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit() : super(const ReviewInitial());

  String? _workspacePath;

  Future<void> loadWorkspace(String workspacePath) async {
    _workspacePath = workspacePath;
    emit(const ReviewLoaded(fileTree: [], changedFiles: []));
    await refresh();
  }

  Future<void> refresh() async {
    final path = _workspacePath;
    if (path == null) return;

    final current = _loaded;
    final fileTree = await _buildFileTree(path);
    final changedFiles = await DiffService.instance.getChangedFiles(path);

    emit(ReviewLoaded(
      fileTree: fileTree,
      changedFiles: changedFiles,
      selectedFilePath: current?.selectedFilePath,
      diffHunks: current?.diffHunks ?? [],
      fileContent: current?.fileContent,
      fileLanguage: current?.fileLanguage,
      viewMode: current?.viewMode ?? ReviewViewMode.diff,
      prStatus: current?.prStatus,
    ));
  }

  Future<void> selectFile(String absolutePath) async {
    final current = _loaded;
    if (current == null) return;

    emit(current.copyWith(
      selectedFilePath: absolutePath,
      isLoadingDiff: true,
      isLoadingFile: true,
    ));

    final workspacePath = _workspacePath ?? '';
    final relativePath = p.relative(absolutePath, from: workspacePath);

    // Load diff and file content in parallel
    final diffFuture = DiffService.instance.getDiff(workspacePath, relativePath);
    final fileFuture = FileViewerService.instance.readFile(absolutePath);

    final results = await Future.wait([diffFuture, fileFuture]);
    final hunks = results[0] as List<DiffHunk>;
    final fileResult = results[1] as FileViewResult;

    if (!isClosed) {
      emit(current.copyWith(
        selectedFilePath: absolutePath,
        diffHunks: hunks,
        fileContent: fileResult.content,
        fileLanguage: fileResult.language,
        isLoadingDiff: false,
        isLoadingFile: false,
      ));
    }
  }

  void setViewMode(ReviewViewMode mode) {
    final current = _loaded;
    if (current == null) return;
    emit(current.copyWith(viewMode: mode));
  }

  void toggleNode(String nodePath) {
    final current = _loaded;
    if (current == null) return;
    final updatedTree = _toggleNodeInTree(current.fileTree, nodePath);
    emit(current.copyWith(fileTree: updatedTree));
  }

  Future<void> stageFile(String filePath) async {
    final workspacePath = _workspacePath;
    if (workspacePath == null) return;
    await GitService.instance.stageFile(workspacePath, filePath);
    await refresh();
  }

  Future<void> unstageFile(String filePath) async {
    final workspacePath = _workspacePath;
    if (workspacePath == null) return;
    await GitService.instance.unstageFile(workspacePath, filePath);
    await refresh();
  }

  Future<List<FileTreeNode>> _buildFileTree(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      final entities = dir.listSync(followLinks: false)
        ..sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
          return a.path.compareTo(b.path);
        });

      return entities
          .where((e) => !p.basename(e.path).startsWith('.'))
          .map((e) {
            final isDir = e is Directory;
            return FileTreeNode(
              name: p.basename(e.path),
              path: e.path,
              isDirectory: isDir,
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<FileTreeNode> _toggleNodeInTree(List<FileTreeNode> nodes, String targetPath) {
    return nodes.map((node) {
      if (node.path == targetPath && node.isDirectory) {
        if (!node.isExpanded) {
          // Expand: load children
          final dir = Directory(targetPath);
          final entities = dir.listSync(followLinks: false)
            ..sort((a, b) {
              final aIsDir = a is Directory;
              final bIsDir = b is Directory;
              if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
              return a.path.compareTo(b.path);
            });
          final children = entities
              .where((e) => !p.basename(e.path).startsWith('.'))
              .map((e) => FileTreeNode(
                    name: p.basename(e.path),
                    path: e.path,
                    isDirectory: e is Directory,
                  ))
              .toList();
          return node.copyWith(isExpanded: true, children: children);
        } else {
          return node.copyWith(isExpanded: false, children: []);
        }
      }
      if (node.isDirectory && node.isExpanded) {
        return node.copyWith(children: _toggleNodeInTree(node.children, targetPath));
      }
      return node;
    }).toList();
  }

  ReviewLoaded? get _loaded {
    final s = state;
    return s is ReviewLoaded ? s : null;
  }
}

import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';

/// Builds file-tree card props from the current review state when it matches the
/// requested repo, otherwise falls back to a shallow filesystem listing.
FileTreeCardProps buildFileTreeCardProps({
  required String repoPath,
  String? repoName,
  dynamic reviewState,
  List<Map<String, dynamic>> Function(String repoPath)? listDirectory,
}) {
  final repoRoots = _findRepoTreeRoots(reviewState, repoPath);
  if (repoRoots.isNotEmpty) {
    final entries = <TreeEntry>[];
    _flattenTreeNodes(repoRoots, entries, 0);
    return FileTreeCardProps(
      repoName: repoName,
      repoPath: repoPath,
      entries: entries,
    );
  }

  if (listDirectory != null && repoPath.isNotEmpty) {
    return FileTreeCardProps(
      repoName: repoName,
      repoPath: repoPath,
      entries: listDirectory(repoPath).map(TreeEntry.fromJson).toList(),
    );
  }

  return FileTreeCardProps(repoName: repoName, repoPath: repoPath);
}

/// Builds diff-card props from the current review state when it matches the
/// requested repo. Non-active repos intentionally show an empty card for now.
DiffCardProps buildDiffCardProps({
  required String repoPath,
  String? repoName,
  dynamic reviewState,
}) {
  final selectedFilePath = _readString(reviewState, 'selectedFilePath');
  if (!_pathIsWithinRepo(selectedFilePath, repoPath)) {
    return DiffCardProps(repoName: repoName, repoPath: repoPath);
  }

  final rawHunks = _readList(reviewState, 'diffHunks');
  if (rawHunks.isEmpty) {
    return DiffCardProps(repoName: repoName, repoPath: repoPath);
  }

  return DiffCardProps(
    repoName: repoName,
    repoPath: repoPath,
    hunks: rawHunks.map(_mapReviewDiffHunk).toList(),
  );
}

List<dynamic> _findRepoTreeRoots(dynamic reviewState, String repoPath) {
  if (repoPath.isEmpty) return const [];
  final fileTree = _readList(reviewState, 'fileTree');
  if (fileTree.isEmpty) return const [];
  return fileTree.where((node) => _readNodePath(node) == repoPath).toList();
}

void _flattenTreeNodes(List<dynamic> nodes, List<TreeEntry> out, int depth) {
  for (final node in nodes) {
    out.add(
      TreeEntry(
        name: _readNodeName(node),
        path: _readNodePath(node),
        isDir: _readNodeIsDir(node),
        depth: depth,
        isExpanded: _readNodeExpanded(node),
      ),
    );
    if (_readNodeExpanded(node)) {
      final children = _readNodeChildren(node);
      if (children.isNotEmpty) {
        _flattenTreeNodes(children, out, depth + 1);
      }
    }
  }
}

DiffHunk _mapReviewDiffHunk(dynamic hunk) {
  final lines = (hunk.lines as List? ?? const [])
      .map(_mapReviewDiffLine)
      .toList();
  return DiffHunk(header: hunk.header as String? ?? '', lines: lines);
}

DiffLine _mapReviewDiffLine(dynamic line) {
  final typeName = line.type?.name as String? ?? '';
  return DiffLine(
    text: line.content as String? ?? '',
    type: switch (typeName) {
      'add' => 'add',
      'remove' => 'remove',
      _ => 'context',
    },
  );
}

String _readString(dynamic object, String field) {
  if (object == null) return '';
  if (object is Map<String, dynamic>) {
    return object[field] as String? ?? '';
  }
  try {
    return switch (field) {
      'selectedFilePath' => object.selectedFilePath as String? ?? '',
      _ => '',
    };
  } catch (_) {
    return '';
  }
}

List<dynamic> _readList(dynamic object, String field) {
  if (object == null) return const [];
  if (object is Map<String, dynamic>) {
    final value = object[field];
    return value is List ? value.cast<dynamic>() : const [];
  }
  try {
    final value = switch (field) {
      'fileTree' => object.fileTree,
      'diffHunks' => object.diffHunks,
      _ => null,
    };
    return value is List ? value.cast<dynamic>() : const [];
  } catch (_) {
    return const [];
  }
}

String _readNodeName(dynamic node) {
  if (node is Map<String, dynamic>) {
    return node['name'] as String? ?? '';
  }
  try {
    return node.name as String? ?? '';
  } catch (_) {
    return '';
  }
}

String _readNodePath(dynamic node) {
  if (node is Map<String, dynamic>) {
    return node['path'] as String? ?? '';
  }
  try {
    return node.path as String? ?? '';
  } catch (_) {
    return '';
  }
}

bool _readNodeIsDir(dynamic node) {
  if (node is Map<String, dynamic>) {
    return (node['isDir'] as bool?) ?? (node['isDirectory'] as bool?) ?? false;
  }
  try {
    return node.isDirectory as bool? ?? false;
  } catch (_) {
    return false;
  }
}

bool _readNodeExpanded(dynamic node) {
  if (node is Map<String, dynamic>) {
    return node['isExpanded'] as bool? ?? false;
  }
  try {
    return node.isExpanded as bool? ?? false;
  } catch (_) {
    return false;
  }
}

List<dynamic> _readNodeChildren(dynamic node) {
  if (node is Map<String, dynamic>) {
    final children = node['children'];
    return children is List ? children.cast<dynamic>() : const [];
  }
  try {
    final children = node.children;
    return children is List ? children.cast<dynamic>() : const [];
  } catch (_) {
    return const [];
  }
}

bool _pathIsWithinRepo(String filePath, String repoPath) {
  if (filePath.isEmpty || repoPath.isEmpty) return false;
  return filePath == repoPath || filePath.startsWith('$repoPath/');
}

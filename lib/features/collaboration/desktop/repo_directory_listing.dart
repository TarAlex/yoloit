import 'dart:io';

import 'package:path/path.dart' as p;

/// Lists top-level directory entries for a repo path (depth 0 + depth 1).
///
/// Used by mindmap file-tree cards when ReviewCubit does not currently own the
/// requested repo, so desktop and browser can fall back to the same shape.
List<Map<String, dynamic>> listRepoDir(String repoPath) {
  final dir = Directory(repoPath);
  if (!dir.existsSync()) return const [];

  final entries = <Map<String, dynamic>>[
    {
      'name': p.basename(repoPath),
      'path': repoPath,
      'isDir': true,
      'depth': 0,
      'isExpanded': true,
    },
  ];

  try {
    final children = dir.listSync()
      ..sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return p.basename(a.path).compareTo(p.basename(b.path));
      });
    for (final child in children.take(50)) {
      final name = p.basename(child.path);
      if (name.startsWith('.') && name != '.github') continue;
      entries.add({
        'name': name,
        'path': child.path,
        'isDir': child is Directory,
        'depth': 1,
        'isExpanded': false,
      });
    }
  } catch (_) {}

  return entries;
}

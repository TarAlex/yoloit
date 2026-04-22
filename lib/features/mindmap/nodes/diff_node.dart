import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/diff_card.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';
import 'package:yoloit/features/review/data/diff_service.dart';
import 'package:yoloit/features/review/models/review_models.dart'
    show FileChange, FileChangeStatus, DiffLineType;

bool _pathIsWithinRepo(String filePath, String repoPath) {
  if (filePath.isEmpty || repoPath.isEmpty) return false;
  return filePath == repoPath || filePath.startsWith('$repoPath/');
}

/// Uses the shared ReviewCubit only for per-file diff hunks.
class DiffNode extends StatefulWidget {
  const DiffNode({super.key, required this.data});
  final DiffNodeData data;

  @override
  State<DiffNode> createState() => _DiffNodeState();
}

class _DiffNodeState extends State<DiffNode> {
  Timer? _timer;
  List<FileChange> _changedFiles = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final path = widget.data.repoPath;
    if (path == null || path.isEmpty) return;
    try {
      final files = await DiffService.instance.getChangedFiles(path);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _changedFiles = files);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _statusName(FileChangeStatus s) {
    switch (s) {
      case FileChangeStatus.added:
        return 'A';
      case FileChangeStatus.deleted:
        return 'D';
      case FileChangeStatus.modified:
        return 'M';
      case FileChangeStatus.renamed:
        return 'R';
      case FileChangeStatus.untracked:
        return 'U';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, state) {
        final cubit = context.read<ReviewCubit>();
        final repoPath = widget.data.repoPath ?? '';

        final changedEntries = _changedFiles
            .map((f) => ChangedFileEntry(
                  path: f.path,
                  name: f.path.split('/').last,
                  status: _statusName(f.status),
                  addedLines: f.addedLines,
                  removedLines: f.removedLines,
                ))
            .toList();

        final selectedFilePath =
            state is ReviewLoaded ? state.selectedFilePath : null;
        final List<DiffHunk> hunks;
        if (state is ReviewLoaded &&
            selectedFilePath != null &&
            _pathIsWithinRepo(selectedFilePath, repoPath)) {
          hunks = state.diffHunks
              .map((h) => DiffHunk(
                    header: h.header,
                    lines: h.lines
                        .map((l) => DiffLine(
                              type: l.type == DiffLineType.add
                                  ? 'add'
                                  : l.type == DiffLineType.remove
                                      ? 'remove'
                                      : 'context',
                              text: l.content,
                            ))
                        .toList(),
                  ))
              .toList();
        } else {
          hunks = const [];
        }

        return DiffCard(
          props: DiffCardProps(
            repoName: widget.data.repoName,
            repoPath: repoPath,
            changedFiles: changedEntries,
            selectedFilePath: selectedFilePath,
            hunks: hunks,
          ),
          onFileTap: (filePath) => cubit.selectFile(filePath),
        );
      },
    );
  }
}

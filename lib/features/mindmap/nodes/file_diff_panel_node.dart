import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/diff_card.dart';
import 'package:yoloit/features/review/data/diff_service.dart';
import 'package:yoloit/features/review/models/review_models.dart'
    show DiffLineType;

/// A standalone panel showing the diff for a single file.
class FileDiffPanelNode extends StatefulWidget {
  const FileDiffPanelNode({super.key, required this.data});
  final FileDiffPanelNodeData data;

  @override
  State<FileDiffPanelNode> createState() => _FileDiffPanelNodeState();
}

class _FileDiffPanelNodeState extends State<FileDiffPanelNode> {
  List<DiffHunk> _hunks = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load());
  }

  Future<void> _load() async {
    final repoPath = widget.data.repoPath;
    final relPath = widget.data.filePath.startsWith('/')
        ? widget.data.filePath.replaceFirst('$repoPath/', '')
        : widget.data.filePath;
    try {
      final rawHunks = await DiffService.instance.getDiff(repoPath, relPath);
      if (mounted) {
        setState(() {
          _loading = false;
          _hunks = rawHunks
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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.data.filePath.split('/').last;
    return DiffCard(
      props: DiffCardProps(
        repoName: fileName,
        repoPath: widget.data.repoPath,
        changedFiles: [],
        selectedFilePath: widget.data.filePath,
        hunks: _loading ? [] : _hunks,
      ),
    );
  }
}

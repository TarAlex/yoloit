import 'package:flutter/material.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/card_props.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/files_card.dart';

class FilesNode extends StatelessWidget {
  const FilesNode({super.key, required this.data});
  final FilesNodeData data;

  @override
  Widget build(BuildContext context) {
    return FilesCard(
      props: FilesCardProps(
        repoPath: data.repoPath,
        files: data.changedFiles.map((f) => FileEntry(
          path: f.path,
          status: f.status.name,
          addedLines: f.addedLines,
          removedLines: f.removedLines,
        )).toList(),
      ),
    );
  }
}

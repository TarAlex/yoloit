import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoloit/features/collaboration/desktop/repo_directory_listing.dart';
import 'package:yoloit/features/editor/bloc/file_editor_cubit.dart';
import 'package:yoloit/features/editor/utils/file_type_utils.dart';
import 'package:yoloit/features/mindmap/bloc/mindmap_cubit.dart';
import 'package:yoloit/features/mindmap/model/mindmap_node_model.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/file_tree_card.dart';
import 'package:yoloit/features/mindmap/nodes/presentation/review_card_props_builder.dart';
import 'package:yoloit/features/review/bloc/review_cubit.dart';
import 'package:yoloit/features/review/bloc/review_state.dart';

/// Mindmap file-tree card — uses the same presentation widget as the browser.
class FileTreeNode extends StatelessWidget {
  const FileTreeNode({super.key, required this.data});
  final FileTreeNodeData data;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewCubit, ReviewState>(
      builder: (context, state) => FileTreeCard(
        props: buildFileTreeCardProps(
          repoPath: data.repoPath ?? '',
          repoName: data.repoName,
          reviewState: state,
          listDirectory: listRepoDir,
        ),
        onToggle: (path) => context.read<ReviewCubit>().toggleNode(path),
        onSelect: (path) => context.read<FileEditorCubit>().openFile(path),
        onNewFolder: (path) async {
          await Directory(path).create(recursive: true);
          if (context.mounted) {
            context.read<ReviewCubit>().toggleNode(path);
          }
        },
        onShowInFinder: (path) => Process.run('open', ['-R', path]),
        onOpenInPanel: (path) => _openInPanel(context, path),
      ),
    );
  }

  void _openInPanel(BuildContext context, String path) async {
    final content =
        await File(path).readAsString().catchError((_) => '');
    final lang = FileTypeUtils.languageFor(path) ?? '';
    final nodeId = 'editor:${path.hashCode}';
    if (!context.mounted) return;
    context.read<MindMapCubit>().openFileAsPanel(
      id: nodeId,
      filePath: path,
      content: content,
      language: lang,
    );
  }
}
